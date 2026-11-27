const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");
const script = fs.readFileSync(path.join(__dirname, "../scripts/carrera-sheet/Reservas.gs"), "utf8");

test("reads Gmail body data returned as bytes or unpadded base64url", () => {
  const content = "Referencia / concepto de pago: CARRERA-0001\nPrueba técnica × €";
  const bytes = Buffer.from(content);
  const context = vm.createContext({
    Utilities: {
      base64Decode(encoded) {
        assert.equal(encoded.length % 4, 0);
        return Buffer.from(encoded, "base64");
      },
      newBlob(data) {
        return { getDataAsString: () => Buffer.from(data).toString("utf8") };
      },
    },
  });
  vm.runInContext(script, context);
  for (const data of [Int8Array.from(bytes), bytes.toString("base64url")]) {
    assert.equal(context.cuerpoTexto({ mimeType: "text/plain", body: { data } }), content);
  }
});

test("reconciles status changes from Gmail or the Sheet", () => {
  const context = vm.createContext({});
  vm.runInContext(script, context);
  const { estadoReserva, estadoSincronizado } = context;
  const labels = new Map([["pending", "Pendiente de pago"], ["paid", "Pagado"], ["picked", "Dorsales entregados"]]);
  assert.equal(estadoReserva(["paid", "pending"], labels, 20, "Pendiente de pago"), "Pagado");
  assert.equal(estadoReserva(["paid", "picked"], labels, 20, "Dorsales entregados"), "Pagado");
  assert.equal(estadoReserva([], labels, 0), "Listo para recoger");
  assert.equal(estadoSincronizado("Pendiente de pago", "Pagado", "Pendiente de pago"), "Pagado");
  assert.equal(estadoSincronizado("Pagado", "Pendiente de pago", "Pendiente de pago"), "Pagado");
  assert.equal(estadoSincronizado("Pagado", "Dorsales entregados", "Pendiente de pago"), "Pagado");
});

test("Gmail updates touch only competing reservation labels", () => {
  const changes = [];
  const context = vm.createContext({
    Gmail: { Users: { Threads: { modify: (...args) => changes.push(args) } } },
  });
  vm.runInContext(script, context);
  const labels = new Map([["Pendiente de pago", "pending"], ["Pagado", "paid"]]);
  context.ajustarEtiqueta("thread", ["pending", "INBOX", "carrera"], labels, "Pagado");
  context.ajustarEtiqueta("thread", ["paid", "INBOX", "carrera"], labels, "Pagado");
  assert.equal(JSON.stringify(changes), JSON.stringify([[{ addLabelIds: ["paid"], removeLabelIds: ["pending"] }, "me", "thread"]]));
});

test("immediately syncs edits to reservation status cells", () => {
  const context = vm.createContext({});
  vm.runInContext(script, context);
  const calls = [];
  context.sincronizarReservas = (...args) => calls.push(args);
  const edit = (name, row, start, end) => context.alCambiarEstado({
    range: {
      getSheet: () => ({ getName: () => name }),
      getLastRow: () => row,
      getColumn: () => start,
      getLastColumn: () => end,
    },
  });
  edit("Reservas", 1, 11, 11);
  edit("Otra hoja", 4, 11, 11);
  edit("Reservas", 4, 2, 10);
  edit("Reservas", 2, 11, 11);
  edit("Reservas", 4, 10, 12);
  context.sincronizarGmail();
  assert.deepEqual(calls, [[], [], [true]]);
});
