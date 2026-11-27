# Hoja de reservas de la Carrera Familiar Solidaria

1. Desde `sanpablodelacruz.madrid@gmail.com`, crea una hoja privada titulada **Carrera Familiar Solidaria — Reservas**.
2. En **Extensiones → Apps Script**, pega el contenido de [Reservas.gs](Reservas.gs) en el archivo de código.
3. En la configuración del proyecto, activa la visualización del manifiesto y sustituye `appsscript.json` por el [manifiesto adjunto](appsscript.json). Google solicita acceso de modificación al buzón para cambiar las etiquetas. El código modifica únicamente las etiquetas de estado de los correos de reservas y edita la hoja vinculada.
4. Añade la propiedad del script `REMITENTE_RESERVAS` con la dirección exacta configurada como remitente de los correos de la carrera.
5. Guarda y ejecuta `instalarSincronizacion`. Google pedirá autorizar el acceso a Gmail y a la hoja. El script crea la pestaña **Reservas** e instala un activador cada cinco minutos. En la hoja, **Carrera → Sincronizar ahora** permite importar sin esperar.
6. En el Gmail de la parroquia, crea las etiquetas **Pendiente de pago**, **Pagado**, **Listo para recoger** y **Dorsales entregados**. Filtra los correos del remitente con asunto `[Carrera]`; para los que incluyen `Sin pago`, aplica **Listo para recoger**. Para el resto, aplica **Pendiente de pago**.
7. Envía una reserva de prueba y comprueba que aparece una fila con su referencia, sus datos e importe. Usa el desplegable **Estado** para marcar **Pagado** después de verificar el importe en la cuenta y **Dorsales entregados** tras la recogida.

La referencia identifica cada fila. El script añade una fila por reserva, ajusta el ancho de las columnas y sincroniza el estado entre Gmail y la hoja. Cuando los dos cambian entre sincronizaciones, prevalece el cambio de la hoja. En Gmail, cada reserva conserva las demás etiquetas y una sola etiqueta de estado. Mantén la hoja restringida al personal autorizado. Las reservas archivadas se importan. Spam y Papelera se excluyen.
