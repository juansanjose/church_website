const form = document.getElementById("race-form");
const submit = form.querySelector('[type="submit"]');
const submitLabel = document.getElementById("race-submit-label");
const registration = document.getElementById("inscripcion");
const error = document.getElementById("race-error");
const donation = document.getElementById("race-donation");
const donationAmount = document.getElementById("race-donation-amount");
const quantityFields = document.getElementById("race-quantities");
const quantities = [...quantityFields.querySelectorAll("[data-price]")];
const euros = new Intl.NumberFormat("es-ES", { style: "currency", currency: "EUR", minimumFractionDigits: 0 });
let previousPayload;
let requestId;

function updateTotal() {
  let cents = 0;
  for (const row of quantities) {
    const input = row.querySelector("input");
    row.querySelector("output").value = input.value;
    const quantity = donation.checked ? 0 : Number(input.value);
    document.getElementById("cantidad-" + row.dataset.category).textContent = quantity;
    if (!Number(row.dataset.price)) continue;
    const subtotal = quantity * Number(row.dataset.price);
    document.getElementById("subtotal-" + row.dataset.category).textContent = euros.format(subtotal);
    cents += subtotal * 100;
  }
  if (donation.checked && donationAmount.validity.valid) cents = Math.round(Number(donationAmount.value) * 100);
  document.getElementById("subtotal-donativo").textContent = euros.format(donation.checked ? cents / 100 : 0);
  document.getElementById("race-total").value = euros.format(cents / 100);
  submitLabel.textContent = (donation.checked ? "Reservar Dorsal 0" : "Reservar mis dorsales") + " · " + euros.format(cents / 100);
}

for (const row of quantities) {
  const input = row.querySelector("input");
  for (const button of row.querySelectorAll("button")) {
    button.addEventListener("click", () => {
      input.value = Math.max(0, Math.min(Number(input.max), Number(input.value) + Number(button.dataset.step)));
      updateTotal();
    });
  }
}

function updateDonation() {
  registration.classList.toggle("modo-cero", donation.checked);
  quantityFields.disabled = donation.checked;
  donationAmount.disabled = !donation.checked;
  donationAmount.required = donation.checked;
  document.getElementById("race-donation-field").hidden = !donation.checked;
  document.getElementById("race-donation-summary").hidden = !donation.checked;
  updateTotal();
}
donation.addEventListener("change", updateDonation);
donationAmount.addEventListener("input", updateTotal);
for (const link of document.querySelectorAll("[data-dorsal0]")) {
  link.addEventListener("click", () => {
    donation.checked = true;
    updateDonation();
  });
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (submit.disabled) return;
  error.hidden = true;
  const order = {
    adultos: "0", ninos: "0", menores: "0", ...Object.fromEntries(new FormData(form)),
    donation_cents: donation.checked ? Math.round(Number(donationAmount.value) * 100) : 0,
  };
  if (!donation.checked && ![order.adultos, order.ninos, order.menores].some((value) => Number(value) > 0)) {
    error.textContent = "Selecciona al menos un dorsal.";
    error.hidden = false;
    return;
  }

  const payload = JSON.stringify(order);
  if (payload !== previousPayload) {
    requestId = crypto.randomUUID();
    previousPayload = payload;
  }
  const controls = [...form.elements].filter((field) => !field.disabled && field.tagName !== "FIELDSET");
  controls.forEach((field) => { field.disabled = true; });
  submitLabel.textContent = "Enviando…";
  let saved = false;
  try {
    const response = await fetch(form.action, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...order, request_id: requestId }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "No se pudo enviar la reserva.");
    saved = true;
    try {
      sessionStorage.setItem("carrera-reservation", JSON.stringify(result));
      location.assign("/carrera-familiar-solidaria/gracias/");
    } catch {
      const status = document.getElementById("race-saved");
      status.textContent = "Reserva recibida. Referencia: " + result.reference + ". Importe: " + euros.format(result.total_cents / 100) + ".";
      status.hidden = false;
      submitLabel.textContent = "Reserva recibida";
    }
  } catch (failure) {
    error.textContent = failure instanceof SyntaxError || failure instanceof TypeError
      ? "No se pudo conectar. Vuelve a intentar con los mismos datos."
      : failure.message;
    error.hidden = false;
  } finally {
    if (!saved) {
      controls.forEach((field) => { field.disabled = false; });
      updateDonation();
    }
  }
});
submit.disabled = false;
donation.checked ||= new URLSearchParams(location.search).get("dorsal") === "0";
updateDonation();
