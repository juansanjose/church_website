const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

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
  const script = path.join(__dirname, "../scripts/carrera-sheet/Reservas.gs");
  vm.runInContext(fs.readFileSync(script, "utf8"), context);
  for (const data of [Int8Array.from(bytes), bytes.toString("base64url")]) {
    assert.equal(context.cuerpoTexto({ mimeType: "text/plain", body: { data } }), content);
  }
});
