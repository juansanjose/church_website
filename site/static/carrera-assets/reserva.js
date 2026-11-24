const booking = document.querySelector("[data-race-booking]");
const form = booking.querySelector("form");
const submit = form.querySelector('[type="submit"]');
const error = document.getElementById("race-error");
const quantities = [...form.querySelectorAll("[data-price]")];
const euros = new Intl.NumberFormat("es-ES", { style: "currency", currency: "EUR" });
let previousPayload;
let requestId;

function updateTotal() {
  const total = quantities.reduce((sum, row) => {
    const quantity = row.querySelector("input");
    return sum + (quantity.validity.valid ? Number(quantity.value) : 0) * Number(row.dataset.price);
  }, 0);
  document.getElementById("race-total").value = euros.format(total);
}

for (const row of quantities) {
  const input = row.querySelector("input");
  for (const button of row.querySelectorAll("button")) {
    button.addEventListener("click", () => {
      input.value = Math.max(0, Math.min(Number(input.max), Number(input.value) + Number(button.dataset.step)));
      updateTotal();
    });
  }
  input.addEventListener("input", updateTotal);
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  error.hidden = true;
  const order = Object.fromEntries(new FormData(form));
  if (![order.adultos, order.ninos, order.menores].some((value) => Number(value) > 0)) {
    error.textContent = "Selecciona al menos un dorsal.";
    error.hidden = false;
    return;
  }

  const payload = JSON.stringify(order);
  if (payload !== previousPayload) {
    requestId = crypto.randomUUID();
    previousPayload = payload;
  }
  const fields = form.querySelectorAll("input");
  fields.forEach((field) => { field.readOnly = true; });
  const buttons = form.querySelectorAll("button");
  buttons.forEach((button) => { button.disabled = true; });
  submit.textContent = "Enviando…";
  try {
    const response = await fetch(form.action, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...order, request_id: requestId }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "No se pudo enviar la reserva.");
    document.getElementById("race-reference").textContent = result.reference;
    document.getElementById("race-amount").textContent = euros.format(result.total_cents / 100);
    document.getElementById("race-transfer").textContent = result.transfer;
    document.getElementById("race-bizum-details").textContent = result.bizum;
    document.getElementById("race-bizum").hidden = !result.bizum;
    document.getElementById("race-pickup").textContent = result.pickup;
    document.getElementById("race-payment").hidden = result.total_cents === 0;
    form.hidden = true;
    document.getElementById("race-confirmation").hidden = false;
    document.getElementById("race-confirmation-title").focus();
  } catch (failure) {
    error.textContent = failure instanceof SyntaxError || failure instanceof TypeError
      ? "No se pudo conectar. Vuelve a intentar con los mismos datos."
      : failure.message;
    error.hidden = false;
  } finally {
    fields.forEach((field) => { field.readOnly = false; });
    buttons.forEach((button) => { button.disabled = false; });
    submit.textContent = "Reservar dorsales";
  }
});

document.getElementById("race-copy").addEventListener("click", async () => {
  const reference = document.getElementById("race-reference").textContent;
  const status = document.getElementById("race-copy-status");
  try {
    await navigator.clipboard.writeText(reference);
    status.textContent = "Concepto copiado.";
  } catch {
    status.textContent = "Copia manualmente la referencia que aparece arriba.";
  }
});
submit.disabled = false;
