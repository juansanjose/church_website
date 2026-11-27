const CABECERAS = [
  "Referencia", "Fecha de reserva", "Nombre", "Apellidos", "Email",
  "Adultos", "Niños", "Menores de 3 años", "Dorsal 0 (€)", "Total (€)", "Estado", "Correo en Gmail",
];

function instalarSincronizacion() {
  sincronizarReservas();
  if (!ScriptApp.getProjectTriggers().some((trigger) => trigger.getHandlerFunction() === "sincronizarReservas")) {
    ScriptApp.newTrigger("sincronizarReservas").timeBased().everyMinutes(15).create();
  }
}

function sincronizarReservas() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) return;
  try {
    const configured = PropertiesService.getScriptProperties().getProperty("REMITENTE_RESERVAS") || "";
    const sender = configured.trim().toLowerCase();
    if (!/^[\w.!#$%&'*+/=?^{}|~-]+@[\w.-]+\.[a-z]{2,}$/i.test(sender)) {
      throw new Error("Configura REMITENTE_RESERVAS con la dirección del remitente SMTP.");
    }
    if (Gmail.Users.getProfile("me").emailAddress.toLowerCase() !== "sanpablodelacruz@gmail.com") {
      throw new Error("Ejecuta el proyecto desde la cuenta de Gmail de la parroquia.");
    }

    const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = spreadsheet.getSheetByName("Reservas") || spreadsheet.insertSheet("Reservas");
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(CABECERAS);
      sheet.setFrozenRows(1);
      sheet.getRange("A1:L1").setFontWeight("bold");
    }
    const existing = new Map();
    const lastRow = sheet.getLastRow();
    if (lastRow > 1) {
      sheet.getRange(2, 1, lastRow - 1, CABECERAS.length).getValues().forEach((values, index) => {
        existing.set(values[0], { row: index + 2, status: values[10] });
      });
    }
    const labels = new Map((Gmail.Users.Labels.list("me").labels || []).map(({ id, name }) => [id, name]));
    let pageToken;
    const imported = [];
    do {
      const result = Gmail.Users.Threads.list("me", { q: "from:" + sender + " subject:CARRERA", maxResults: 100, pageToken });
      for (const { id } of result.threads || []) {
        const thread = Gmail.Users.Threads.get("me", id, { format: "full" });
        for (const message of thread.messages || []) {
          const header = (name) => (message.payload.headers || []).find((h) => h.name.toLowerCase() === name)?.value || "";
          const from = header("from").trim().match(/<([^<>]+)>$|^([^<>\s]+)$/);
          const subject = header("subject");
          if ((from?.[1] || from?.[2] || "").toLowerCase() !== sender || !/^\[Carrera\] CARRERA-\d{4,} \|/.test(subject)) continue;
          const body = cuerpoTexto(message.payload);
          const reservation = leerReserva(body);
          if (!reservation || !subject.startsWith("[Carrera] " + reservation[0] + " |")) continue;
          const status = estadoReserva(message.labelIds || [], labels, reservation[8]);
          const previous = existing.get(reservation[0]);
          if (previous) {
            if (previous.row && status !== previous.status) sheet.getRange(previous.row, 11).setValue(status);
            continue;
          }
          const [reference, first, last, email, adults, children, infants, donation, total] = reservation;
          imported.push([
            reference, new Date(Number(message.internalDate)), first, last, email,
            adults, children, infants, donation, total, status,
            "https://mail.google.com/mail/u/0/#all/" + id,
          ]);
          existing.set(reference, {});
        }
      }
      pageToken = result.nextPageToken;
    } while (pageToken);
    if (imported.length) {
      const firstRow = sheet.getLastRow() + 1;
      sheet.getRange(firstRow, 1, imported.length, CABECERAS.length).setValues(imported);
      sheet.getRange(firstRow, 2, imported.length, 1).setNumberFormat("dd/MM/yyyy HH:mm");
      sheet.getRange(firstRow, 9, imported.length, 2).setNumberFormat('0.00 "€"');
    }
    SpreadsheetApp.flush();
  } finally {
    lock.releaseLock();
  }
}

function cuerpoTexto(part) {
  if (part.mimeType === "text/plain" && part.body?.data) {
    return Utilities.newBlob(Utilities.base64DecodeWebSafe(part.body.data)).getDataAsString("UTF-8");
  }
  for (const nested of part.parts || []) {
    const body = cuerpoTexto(nested);
    if (body) return body;
  }
  return "";
}

function leerReserva(body) {
  const field = (label) => body.split(/\r?\n/).find((line) => line.startsWith(label + ": "))?.slice(label.length + 2) || "";
  const safe = (value) => /^\s*[=+@-]/.test(value) ? "'" + value : value;
  const quantity = (value) => /^(\d{1,2}) × /.exec(value)?.[1];
  const money = (value) => /^\d+,\d{2} €$/.test(value) ? Number(value.replace(",", ".").slice(0, -2)) : NaN;
  const reference = field("Referencia / concepto de pago");
  const first = field("Nombre") || field("Nombre y apellidos");
  const email = field("Email de contacto");
  const quantities = ["Adultos", "Niños", "Menores de 3 años"].map((label) => quantity(field(label)));
  const donation = money(field("Dorsal 0") || "0,00 €");
  const total = money(field("Importe a comprobar"));
  if (!/^CARRERA-\d{4,}$/.test(reference) || !first || !email ||
      quantities.some((value) => value === undefined) || !Number.isFinite(donation) || !Number.isFinite(total)) return null;
  return [reference, safe(first), safe(field("Apellidos")), safe(email), ...quantities.map(Number), donation, total];
}

function estadoReserva(ids, labels, total) {
  const applied = ids.map((id) => (labels.get(id) || "").split("/").pop().toLowerCase());
  if (applied.includes("dorsales entregados")) return "Dorsales entregados";
  if (applied.includes("pagado")) return "Pagado";
  return total === 0 ? "Listo para recoger" : "Pendiente de pago";
}
