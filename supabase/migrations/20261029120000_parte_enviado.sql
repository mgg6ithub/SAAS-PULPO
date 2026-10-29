-- DEV-029: el PDF del parte se manda por email al cliente al guardarlo (Edge Function «enviar-parte»).
-- Se apunta a quién y cuándo; con esto la función no lo manda dos veces.
alter table public.informes
  add column parte_enviado_a text,
  add column parte_enviado_en timestamptz;
comment on column public.informes.parte_enviado_a is 'Correo del cliente al que se mandó el PDF del parte.';
comment on column public.informes.parte_enviado_en is 'Cuándo se mandó el PDF del parte al cliente (null = aún no).';
