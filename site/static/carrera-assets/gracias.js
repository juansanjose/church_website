let reservation;
try {
  reservation = JSON.parse(sessionStorage.getItem("carrera-reservation"));
} catch {
  // The page may be opened independently or with storage disabled.
}

if (!/^CARRERA-\d{4,}$/.test(reservation?.reference ?? "") ||
    !Number.isSafeInteger(reservation?.total_cents) || reservation.total_cents < 0) {
  document.getElementById("sin-reserva").hidden = false;
} else {
  const { reference, total_cents: cents, dorsal_cero: donation } = reservation;
  document.getElementById("confirmacion").hidden = false;
  document.getElementById("referencia").textContent = reference;
  document.getElementById("concepto").textContent = reference;
  document.getElementById("importe").textContent = new Intl.NumberFormat("es-ES", {
    style: "currency", currency: "EUR",
  }).format(cents / 100);
  document.body.classList.toggle("es-cero", donation === true);
  if (cents === 0) {
    document.body.classList.add("sin-pago");
    document.getElementById("paso-pago").hidden = true;
    document.getElementById("numero-recogida").textContent = "1";
    document.getElementById("numero-carrera").textContent = "2";
  }

  for (const button of document.querySelectorAll("[data-copiar], #copiarConcepto")) {
    const label = button.textContent;
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copiar ?? reference);
        button.textContent = "¡Copiado!";
      } catch {
        button.textContent = "Copia el dato manualmente";
      }
      setTimeout(() => { button.textContent = label; }, 1500);
    });
  }

  const shareUrl = new URL("/carrera-familiar-solidaria/", location.origin);
  document.getElementById("whatsapp").href += encodeURIComponent(
    "¡Te invito a la Carrera Familiar Solidaria de la Parroquia San Pablo de la Cruz! " + shareUrl,
  );
}
