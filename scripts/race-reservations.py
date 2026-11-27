"""Accept race reservations and send the parish notification from a durable outbox."""

import json
import logging
import os
import re
import smtplib
import sqlite3
import ssl
import threading
from contextlib import closing
from email.message import EmailMessage
from email.utils import formatdate
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from time import time
from uuid import UUID

PARISH_EMAIL = "sanpablodelacruz@gmail.com"
API_PATH = "/api/carrera/reservas"
CATEGORIES = (
    ("adultos", "Adultos", 1500),
    ("ninos", "Niños", 500),
    ("menores", "Menores de 3 años", 0),
)
BUSY = "Hay muchas solicitudes. Inténtalo de nuevo en un minuto."


class InvalidOrder(ValueError):
    pass


def amount(cents):
    return f"{cents // 100},{cents % 100:02d} €"


def reference(order):
    return f"CARRERA-{order['id']:04d}"


def parse_order(data):
    if not isinstance(data, dict) or data.get("website"):
        raise InvalidOrder("Revisa los datos de la reserva.")
    if data.get("privacy") != "yes":
        raise InvalidOrder("Confirma que has leído la política de privacidad.")
    order = {}
    for field, limit in (("nombre", 80), ("apellidos", 100), ("email", 254)):
        value = data.get(field)
        if not isinstance(value, str) or not 1 <= len(value.strip()) <= limit:
            raise InvalidOrder("Completa el nombre, los apellidos y el correo electrónico.")
        if any(ord(char) < 32 or ord(char) == 127 or 0xD800 <= ord(char) <= 0xDFFF for char in value):
            raise InvalidOrder("Revisa los datos de contacto.")
        order[field] = value.strip()
    if not re.fullmatch(r"[^\s@<>]+@[^\s@<>.]+(?:\.[^\s@<>.]+)+", order["email"]):
        raise InvalidOrder("Introduce un correo electrónico válido.")
    try:
        order["request_id"] = str(UUID(data["request_id"]))
    except (AttributeError, KeyError, TypeError, ValueError):
        raise InvalidOrder("Vuelve a cargar la página e inténtalo de nuevo.") from None

    for field, _, _ in CATEGORIES:
        value = data.get(field)
        if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,2}", value):
            raise InvalidOrder("Introduce una cantidad entre 0 y 99 en cada categoría.")
        order[field] = int(value)
    donation = data.get("donation_cents", 0)
    if type(donation) is not int or not 0 <= donation <= 999999:
        raise InvalidOrder("Introduce un importe válido para el Dorsal 0.")
    participants = sum(order[field] for field, _, _ in CATEGORIES)
    if donation and participants:
        raise InvalidOrder("El Dorsal 0 es para quienes no participarán en la carrera.")
    if not (participants or donation):
        raise InvalidOrder("Selecciona al menos un dorsal.")
    order["donation_cents"] = donation
    order["total_cents"] = donation + sum(order[field] * price for field, _, price in CATEGORIES)
    return order


def initialize(database):
    with closing(sqlite3.connect(database)) as connection, connection:
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute("""
            CREATE TABLE IF NOT EXISTS reservations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                request_id TEXT UNIQUE NOT NULL,
                nombre TEXT NOT NULL,
                apellidos TEXT NOT NULL,
                email TEXT NOT NULL,
                adultos INTEGER NOT NULL,
                ninos INTEGER NOT NULL,
                menores INTEGER NOT NULL,
                donation_cents INTEGER NOT NULL DEFAULT 0,
                total_cents INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                email_sent INTEGER,
                next_attempt INTEGER NOT NULL DEFAULT 0
            )
        """)
        if "donation_cents" not in {column[1] for column in connection.execute("PRAGMA table_info(reservations)")}:
            connection.execute("ALTER TABLE reservations ADD COLUMN donation_cents INTEGER NOT NULL DEFAULT 0")


def save_order(database, order):
    with closing(sqlite3.connect(database)) as connection, connection:
        connection.row_factory = sqlite3.Row
        connection.execute("BEGIN IMMEDIATE")
        existing = connection.execute(
            "SELECT * FROM reservations WHERE request_id = ?", (order["request_id"],)
        ).fetchone()
        if existing:
            if any(existing[field] != value for field, value in order.items()):
                return 409, {"error": "La referencia de envío ya está asociada a otra reserva."}
            return 200, existing
        now = int(time())
        recent = connection.execute(
            "SELECT COUNT(*) FROM reservations WHERE created_at > ?", (now - 60,)
        ).fetchone()[0]
        if recent >= 40:
            return 429, {"error": BUSY}
        inserted = connection.execute("""
            INSERT INTO reservations
                (request_id, nombre, apellidos, email, adultos, ninos, menores, donation_cents, total_cents, created_at)
            VALUES (:request_id, :nombre, :apellidos, :email, :adultos, :ninos, :menores, :donation_cents, :total_cents, :created_at)
        """, {**order, "created_at": now})
        return 201, connection.execute(
            "SELECT * FROM reservations WHERE id = ?", (inserted.lastrowid,)
        ).fetchone()


def make_message(order, sender):
    ref = reference(order)
    name = f"{order['nombre']} {order['apellidos']}"
    total = amount(order["total_cents"])
    free = order["total_cents"] == 0
    message = EmailMessage()
    message["From"] = sender
    message["To"] = PARISH_EMAIL
    message["Subject"] = f"[Carrera] {ref} | {name} | {total}" + (" | Sin pago" if free else "")
    message["Date"] = formatdate(order["created_at"], usegmt=True)
    message["Message-ID"] = f"<{order['request_id']}.carrera@sanpablodelacruz.com>"
    lines = [
        "RESERVA DE DORSALES",
        "",
        f"Referencia / concepto de pago: {ref}",
        f"Estado al recibir la reserva: {'Sin pago' if free else 'Pendiente de pago'}",
        "",
        f"Nombre y apellidos: {name}",
        f"Nombre: {order['nombre']}",
        f"Apellidos: {order['apellidos']}",
        f"Email de contacto: {order['email']}",
        "",
    ]
    for field, label, price in CATEGORIES:
        quantity = order[field]
        lines.append(f"{label}: {quantity} × {amount(price)} = {amount(quantity * price)}")
    lines.append(f"Dorsal 0: {amount(order['donation_cents'])}")
    lines.extend(("", f"Importe a comprobar: {total}"))
    message.set_content("\n".join(lines))
    return message


def send_notifications(database, smtp, signal):
    security = ssl.create_default_context()
    while True:
        signal.clear()
        try:
            with closing(sqlite3.connect(database)) as connection, connection:
                connection.row_factory = sqlite3.Row
                order = connection.execute("""
                    SELECT * FROM reservations
                    WHERE email_sent IS NULL AND next_attempt <= ? ORDER BY id LIMIT 1
                """, (int(time()),)).fetchone()
                if order:
                    with smtplib.SMTP_SSL(smtp["host"], smtp["port"], timeout=15, context=security) as mail:
                        mail.login(smtp["user"], smtp["password"])
                        mail.send_message(make_message(order, smtp["sender"]))
                        connection.execute(
                            "UPDATE reservations SET email_sent = ? WHERE id = ?",
                            (int(time()), order["id"]),
                        )
                        connection.commit()
                    continue
        except (OSError, smtplib.SMTPException) as failure:
            logging.warning("Could not deliver race notification (%s). Retrying in 10 minutes.",
                            type(failure).__name__)
            with closing(sqlite3.connect(database)) as connection, connection:
                connection.execute(
                    "UPDATE reservations SET next_attempt = ? WHERE email_sent IS NULL",
                    (int(time()) + 600,),
                )
        except sqlite3.Error:
            logging.exception("Could not check pending race notifications")
        signal.wait(timeout=60)


class ReservationHandler(BaseHTTPRequestHandler):
    def setup(self):
        self.request.settimeout(10)
        super().setup()

    def reply(self, status, result):
        content = json.dumps(result, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True})
        else:
            self.reply(404, {"error": "Ruta no disponible."})

    def do_POST(self):
        if self.path != API_PATH:
            self.reply(404, {"error": "Ruta no disponible."})
            return
        if self.headers.get("Origin") != self.server.origin:
            self.reply(403, {"error": "Envía la reserva desde la página de la parroquia."})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 4096 or self.headers.get_content_type() != "application/json":
                raise ValueError
            order = parse_order(json.loads(self.rfile.read(size)))
        except InvalidOrder as invalid:
            self.reply(400, {"error": str(invalid)})
            return
        except (ValueError, RecursionError):
            self.reply(400, {"error": "Revisa los datos de la reserva."})
            return

        try:
            status, saved = save_order(self.server.database, order)
        except sqlite3.Error:
            logging.exception("Could not save race reservation")
            self.reply(503, {"error": "No se pudo guardar la reserva. Vuelve a intentarlo."})
            return
        if status >= 400:
            self.reply(status, saved)
            return
        self.server.notification.set()
        self.reply(status, {
            "reference": reference(saved),
            "total_cents": saved["total_cents"],
            "dorsal_cero": saved["donation_cents"] > 0,
        })


def serve():
    database = Path(os.environ.get("RACE_DATABASE", "/var/lib/church-race/reservations.sqlite3"))
    smtp = {
        "host": os.environ["RACE_SMTP_HOST"],
        "port": int(os.environ.get("RACE_SMTP_PORT", "465")),
        "user": os.environ["RACE_SMTP_USER"],
        "password": os.environ["RACE_SMTP_PASSWORD"],
        "sender": os.environ.get("RACE_SMTP_FROM") or os.environ["RACE_SMTP_USER"],
    }
    if not all(smtp.values()):
        raise ValueError("Configure SMTP for race notification delivery.")
    initialize(database)
    with ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("RACE_PORT", "8091"))),
                             ReservationHandler) as server:
        server.database = database
        server.origin = os.environ.get("RACE_ORIGIN", "https://www.sanpablodelacruz.com")
        server.notification = threading.Event()
        threading.Thread(target=send_notifications, daemon=True,
                         args=(database, smtp, server.notification)).start()
        server.serve_forever()


if __name__ == "__main__":
    serve()
