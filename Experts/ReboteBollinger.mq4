/*
EA que se pone contrario cada vez que se toca una de las bandas de Bollinguer, saliendo cuando toquemos
la banda contraria. Por lo tanto:
- Cierra la operación actual larga y mete una corta cuando el precio sea >= banda superior de Bollinguer
- Cierra la operación actual corta y mete una larga cuando el precio sea <= banda inferior de Bollinguer
*/

#property strict // Sirve para exigir que se programe bien

// Parámetros del EA
extern double lotaje = 0.1; // Lotaje de las operaciones
extern uint periodo = 14; // Periodo para Bollinguer
extern uint desviaciones = 2; // Desviaciones típicas para Bollinguer

// Variables globales
int idOperacionLarga; // Id de nuestra operación larga viva actual. -1 si no hay ninguna viva larga
int idOperacionCorta; // Id de nuestra operación corta viva actual. -1 si no hay ninguna viva corta

// Función que se ejecuta al inicio del EA
int OnInit(){
   idOperacionLarga = -1; // Al principio, no hay ninguna operacion viva, ni larga ni corta
   idOperacionCorta = -1; // Al principio, no hay ninguna operacion viva, ni larga ni corta
   return(INIT_SUCCEEDED);
}

// Función que se ejecuta cada tick
void OnTick(){
   
   // Calculamos las bandas de Bollinguer
   double bandaSuperior = iBands(NULL,0,periodo,desviaciones,0,PRICE_CLOSE,MODE_UPPER,0);
   double bandaInferior = iBands(NULL,0,periodo,desviaciones,0,PRICE_CLOSE,MODE_LOWER,0);
   
   // Si estamos por encima de la banda superior, cerramos la larga vieja y metemos una corta nueva
   if (Bid >= bandaSuperior) {
      
      // Si tenemos una larga, la cerramos
      if (idOperacionLarga != -1) {
         bool exitoEnCerrar = OrderClose(idOperacionLarga,lotaje,Bid,0); // Para cerrar una larga, hay que hacer una venta. Por tanto es Bid
         if (exitoEnCerrar) idOperacionLarga = -1;
      }
      
      // Si no tenemos aún la corta metida, la metemos
      if (idOperacionCorta == -1) {
         idOperacionCorta = OrderSend(NULL,OP_SELL,lotaje,Bid,0,0,0);
      }
   
   }   
   
   // Si estamos por debajo de la banda inferior , cerramos la corta vieja y metemos una larga nueva
   if (Bid <= bandaInferior) {
      
      // Si tenemos una corta, la cerramos
      if (idOperacionCorta != -1) {
         bool exitoEnCerrar = OrderClose(idOperacionCorta,lotaje,Ask,0); // Para cerrar una larga, hay que hacer una venta. Por tanto es Bid
         if (exitoEnCerrar) idOperacionCorta = -1;
      }
      
      // Si no tenemos aún la larga metida, la metemos
      if (idOperacionLarga == -1) {
         idOperacionLarga = OrderSend(NULL,OP_BUY,lotaje,Ask,0,0,0);
      }
   
   }
     
}

