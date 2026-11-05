-- Pultec: las órdenes de trabajo ya no se crean solas. Un mantenimiento sin orden se queda en
-- «Mantenimientos sin orden de trabajo» hasta que alguien la crea. Se siguen encolando los avisos previos.
select cron.unschedule('ipultec-mantenimientos');
select cron.schedule('ipultec-mantenimientos', '7 * * * *', $cron$
  select private.encolar_avisos_planes();
$cron$);
