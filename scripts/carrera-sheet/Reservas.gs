const CABECERAS = [
  "Referencia", "Fecha de reserva", "Nombre", "Apellidos", "Email",
  "Adultos", "Niños", "Menores de 3 años", "Dorsal 0 (€)", "Total (€)", "Estado", "Correo en Gmail",
];
const COLUMNA_ESTADO = 11;
const COLUMNA_ENLACE = 12;
const COLUMNA_GMAIL = 13;
const ESTADOS = ["Pendiente de pago", "Pagado", "Listo para recoger", "Dorsales entregados"];
const HISTORIAL_GMAIL = "ULTIMO_HISTORIAL_GMAIL";

function onOpen() {
  SpreadsheetApp.getUi().createMenu("Carrera")
    .addItem("Sincronizar ahora", "sincronizarReservas")
    .addToUi();
}

function instalarSincronizacion() {
  sincronizarReservas();
  const handlers = ["sincronizarReservas", "sincronizarGmail", "alCambiarEstado"];
  const oldTriggers = ScriptApp.getProjectTriggers().filter((trigger) => handlers.includes(trigger.getHandlerFunction()));
  ScriptApp.newTrigger("alCambiarEstado").forSpreadsheet(SpreadsheetApp.getActive()).onEdit().create();
  ScriptApp.newTrigger("sincronizarGmail").timeBased().everyMinutes(1).create();
  oldTriggers.forEach((trigger) => ScriptApp.deleteTrigger(trigger));
}

function alCambiarEstado(event) {
  const range = event.range;
  if (range.getSheet().getName() === "Reservas" && range.getLastRow() >= 2 &&
      range.getColumn() <= COLUMNA_ESTADO && range.getLastColumn() >= COLUMNA_ESTADO) {
    sincronizarReservas();
  }
}

function sincronizarGmail() {
  sincronizarReservas(true);
}

function sincronizarReservas(soloSiHayCambios = false) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) return;
  try {
    const properties = PropertiesService.getScriptProperties();
    const configured = properties.getProperty("REMITENTE_RESERVAS") || "";
    const sender = configured.trim().toLowerCase();
    if (!/^[\w.!#$%&'*+/=?^{}|~-]+@[\w.-]+\.[a-z]{2,}$/i.test(sender)) {
      throw new Error("Configura REMITENTE_RESERVAS con la dirección del remitente SMTP.");
    }
    const profile = Gmail.Users.getProfile("me");
    if (profile.emailAddress.toLowerCase() !== "sanpablodelacruz.madrid@gmail.com") {
      throw new Error("Ejecuta el proyecto desde la cuenta de Gmail de la parroquia.");
    }
    const historyId = String(profile.historyId || "");

    const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = spreadsheet.getSheetByName("Reservas") || spreadsheet.insertSheet("Reservas");
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(CABECERAS);
      sheet.setFrozenRows(1);
      sheet.getRange("A1:L1").setFontWeight("bold");
    }
    const gmailHeader = sheet.getRange(1, COLUMNA_GMAIL);
    if (gmailHeader.isBlank()) {
      gmailHeader.setValue("Estado importado de Gmail");
      sheet.hideColumns(COLUMNA_GMAIL);
    } else if (gmailHeader.getValue() !== "Estado importado de Gmail") {
      throw new Error("La columna M de Reservas está ocupada.");
    }
    const existing = new Map();
    const lastRow = sheet.getLastRow();
    if (lastRow > 1) {
      sheet.getRange(2, 1, lastRow - 1, COLUMNA_GMAIL).getValues().forEach((values, index) => {
        existing.set(values[0], {
          row: index + 2, status: values[COLUMNA_ESTADO - 1], gmailStatus: values[COLUMNA_GMAIL - 1],
        });
      });
    }
    if (soloSiHayCambios === true && historyId && historyId === properties.getProperty(HISTORIAL_GMAIL) &&
        ![...existing.values()].some(({ status, gmailStatus }) => status !== gmailStatus)) return;
    const labels = new Map((Gmail.Users.Labels.list("me").labels || []).map(({ id, name }) => [id, name]));
    const statusLabels = new Map([...labels].filter(([, name]) => ESTADOS.includes(name)).map(([id, name]) => [name, id]));
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
          const messageLabels = message.labelIds || [];
          const previous = existing.get(reservation[0]);
          const status = estadoReserva(messageLabels, labels, reservation[8], previous?.gmailStatus);
          if (previous) {
            if (previous.row) {
              const next = estadoSincronizado(previous.status, status, previous.gmailStatus);
              ajustarEtiqueta(id, messageLabels, statusLabels, next);
              if (previous.status !== next) sheet.getRange(previous.row, COLUMNA_ESTADO).setValue(next);
              if (previous.gmailStatus !== next) sheet.getRange(previous.row, COLUMNA_GMAIL).setValue(next);
              existing.set(reservation[0], {});
            }
            continue;
          }
          ajustarEtiqueta(id, messageLabels, statusLabels, status);
          const [reference, first, last, email, adults, children, infants, donation, total] = reservation;
          imported.push([
            reference, new Date(Number(message.internalDate)), first, last, email,
            adults, children, infants, donation, total, status,
            "https://mail.google.com/mail/u/0/#all/" + id, status,
          ]);
          existing.set(reference, {});
        }
      }
      pageToken = result.nextPageToken;
    } while (pageToken);
    if (imported.length) {
      const firstRow = sheet.getLastRow() + 1;
      sheet.getRange(firstRow, 1, imported.length, COLUMNA_GMAIL).setValues(imported);
      sheet.getRange(firstRow, 2, imported.length, 1).setNumberFormat("dd/MM/yyyy HH:mm");
      sheet.getRange(firstRow, 9, imported.length, 2).setNumberFormat('0.00 "€"');
    }
    const reservationCount = sheet.getLastRow() - 1;
    if (reservationCount > 0) {
      const rule = SpreadsheetApp.newDataValidation().requireValueInList(ESTADOS, true).setAllowInvalid(false).build();
      sheet.getRange(2, COLUMNA_ESTADO, reservationCount, 1).setDataValidation(rule);
    }
    ajustarColumnas(sheet, reservationCount);
    if (historyId) properties.setProperty(HISTORIAL_GMAIL, historyId);
  } finally {
    lock.releaseLock();
  }
}

function ajustarColumnas(sheet, reservationCount) {
  if (reservationCount > 0) {
    const links = sheet.getRange(2, COLUMNA_ENLACE, reservationCount, 1).getValues();
    links.forEach(([url], index) => {
      if (typeof url === "string" && url.startsWith("https://mail.google.com/mail/u/0/#all/")) {
        const link = SpreadsheetApp.newRichTextValue().setText("Abrir correo").setLinkUrl(url).build();
        sheet.getRange(index + 2, COLUMNA_ENLACE).setRichTextValue(link);
      }
    });
  }
  const visible = sheet.getRange(1, 1, reservationCount + 1, CABECERAS.length);
  visible.setWrap(false);
  SpreadsheetApp.flush();
  sheet.autoResizeColumns(1, CABECERAS.length);
  for (let column = 1; column <= CABECERAS.length; column++) {
    sheet.setColumnWidth(column, Math.min(sheet.getColumnWidth(column) + 12, 420));
  }
  visible.setWrap(true);
  SpreadsheetApp.flush();
  sheet.autoResizeRows(1, reservationCount + 1);
}

function cuerpoTexto(part) {
  if (part.mimeType === "text/plain" && part.body?.data) {
    const data = part.body.data;
    if (typeof data !== "string") {
      return Utilities.newBlob(Array.from(data)).getDataAsString("UTF-8");
    }
    const base64 = data.replace(/-/g, "+").replace(/_/g, "/").replace(/=+$/, "");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    return Utilities.newBlob(Utilities.base64Decode(padded)).getDataAsString("UTF-8");
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

function estadoReserva(ids, labels, total, previousStatus) {
  const applied = ids.map((id) => (labels.get(id) || "").split("/").pop().toLowerCase());
  const states = ESTADOS.slice().reverse().filter((state) => applied.includes(state.toLowerCase()));
  return states.find((state) => state !== previousStatus) ?? states[0] ??
    (total === 0 ? "Listo para recoger" : "Pendiente de pago");
}

function estadoSincronizado(sheetStatus, gmailStatus, previousStatus) {
  if (previousStatus && sheetStatus !== previousStatus && ESTADOS.includes(sheetStatus)) return sheetStatus;
  return gmailStatus;
}

function ajustarEtiqueta(thread, applied, statusLabels, status) {
  const target = statusLabels.get(status);
  if (!target) throw new Error("Falta la etiqueta de Gmail " + status + ".");
  const addLabelIds = applied.includes(target) ? [] : [target];
  const removeLabelIds = [...statusLabels.values()].filter((id) => id !== target && applied.includes(id));
  if (addLabelIds.length || removeLabelIds.length) {
    Gmail.Users.Threads.modify({ addLabelIds, removeLabelIds }, "me", thread);
  }
}
