/*
EA de MT4 que implementa el sistema básico de entrar en compra cuando el precio actual está por encima de su
media exponencial, y en venta cuando el precio actual está por debajo de su media exponencia. Salimos cuando salta el SL o el TP.
*/

#property strict

// Parámetros del EA
extern double lotaje = 0.1; // Lotaje de las operaciones
extern uint periodoMedia = 20; // Numero de velas para calcular la media
extern uint SL = 50; // SL inicial en puntos
extern uint TP = 50; // TP en puntos

// Variables globales
int idOperacion; // Id de nuestra ultima operacion

// Función que se ejecuta al inicio del EA
int OnInit(){
   idOperacion = -1;
   return(INIT_SUCCEEDED);
}

// Función que se ejecuta cada tick
void OnTick(){
   
   // Si no hay operacion abierta, metemos una nueva
   if (!isOperacionAbierta(idOperacion)) {     
     
      // Averiguo la media exponencial
      double media = iMA(NULL, 0, periodoMedia, 0, MODE_EMA, PRICE_CLOSE, 0);
    
      // Metemos operacion. Compra si el precio actual (tomamos Bid) es mayor que la media, y venta si Bid es menor que la media
      if (Bid > media) idOperacion = introducirNuevaOperacion(lotaje, OP_BUY, SL, TP);
      if (Bid < media) idOperacion = introducirNuevaOperacion(lotaje, OP_SELL, SL, TP);
      
   }   
  
}


// Comprueba si una operación cuyo id se proporciona está aún abierta
// Parámetro: identificador de la operación que devuelve OrderSend() cuando la orden se crea
// Retorno: true si la operación sigue abierta, false si está cerrada o bien idOperacion == -1 (la operación no existe)
bool isOperacionAbierta(int idTrade) { 
   if (idTrade==-1) return(false);
   bool resultado=false; // Contendra el resultado
   bool exito = OrderSelect(idTrade, SELECT_BY_TICKET);   
   if (!exito) {
      Print ("ERROR: OrderSelect no funciono al intentar ver si una operacion esta abierta. Asumimos que sigue abierta");
      resultado=true; // Al no poder ver si está abierta, suponemos que es así para no correr el riesgo de meter otra
   }
   else {        
      // Si la operación seleccionada tiene alguna fecha de cerrado, es que ya está efectivamente cerrada
      if (OrderCloseTime() == 0) resultado = true;
      else resultado=false;
   }
   return(resultado);
}



// Introducimos una nueva operacion
// Parámetros:
// - lotaje: lotaje de la nueva operacion
// - sentidoOperacion: puede ser OP_BUY o OP_SELL (constantes predefinidas)
// - distanciaAlSL: distancia en puntos desde la apertura al SL
// - distanciaAlTP: distancia en puntos desde la apertura al TP
// Retorno: identificador de la nueva operacion metida, o -1 si falló
int introducirNuevaOperacion(double lotajeLocal, int sentidoOperacion, int distanciaAlSL, int distanciaAlTP) {
   int idOperacionLocal;
   double precioApertura; // El precio al que se abrió la operación inicialmente 
   double SLLocal, TPLocal; // SL y TP que pondremos en la nueva operación
   
   // Calculamos el precio de apertura al que solicitaremos la operacion
   if (sentidoOperacion == OP_BUY) precioApertura = Ask;
   else precioApertura = Bid;
      
   // Calculamos SL
   if (sentidoOperacion == OP_BUY) SLLocal = precioApertura-distanciaAlSL*Point;
   else SLLocal = precioApertura+distanciaAlSL*Point;
   SLLocal = NormalizeDouble(SLLocal,Digits);
   
   // Calculamos TP
   if (sentidoOperacion == OP_BUY) TPLocal = precioApertura+distanciaAlTP*Point;
   else TPLocal = precioApertura-distanciaAlTP*Point;      
   TPLocal = NormalizeDouble(TPLocal,Digits);
      
   // Intentamos introducir la operación
   idOperacionLocal = OrderSend(Symbol(),sentidoOperacion,lotajeLocal,precioApertura,0,SLLocal,TPLocal);
   
   // Devolvemos el id de la operación, o -1 si hubo algún error
   return(idOperacionLocal);
}