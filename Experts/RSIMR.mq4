/*
Sistema RSIMR (RSI Mean Reversion). 

EA de MT4 que implementa en open price un sistema anti-tendencial (de reversión a la media).
- Entramos antetendencial cuando estamos lo suficientemente lejos de la mediaLarga y además el precio ha dado síntomas de que ha parado su tendencia
- El síntoma de que el precio ha parado es que el RSI sale de la zona extrema
- Ponemos el TP en la mediaLarga. Lo actualizamos en cada vela
- No hay SL
*/

#property strict

#define COPYRIGHT "Dr. CarlosGrima.com (CGI)"
#define LINK      "http://www.carlosgrima.com"
#define VERSION   "1.0"
#define FECHA     20170402
#define NOMBRE    "RSIMR"

#property copyright COPYRIGHT
#property link      LINK
#property version   VERSION

// Parámetros optimizables del EA

   extern uint periodoRSI = 17;
   extern uint periodoEMALarga = 55;
   // Indica la línea frontera de la sobrecompra (50+fronteraRSI) y de sobreventa (50-fronteraRSI)
   extern uint fronteraRSI = 20; 

// Parámetros del EA que NO se deberían optimizar

   // Lotaje inicial de las operaciones (con el balance inicial del mercado). Se va incrementando/decrementando segun vamos ganando/perdiendo dinero
   extern double lotajeInicial = 0.1;
   // Magic number 
   extern int magicNumber = FECHA; 
   // Maximo slippage permitido para meter una operación (en puntos basicos). 
   extern uint slippageMaximo = 10; 
   // nivelLog. Indica la cantidad de informacion que se imprimira en el log. 
   // 0: nada. 1: sólo errores. 2: info normal. 3: info completa (puede generarse info en cada tick!!). Poner 0 en backtest. 
   extern uint nivelLog = 3; 


// Variables globales
   datetime tiempoUltimaVelaProcesada; // Tiempo de apertura de la ultima vela procesada (para implementar "open price")
   bool errorParametros; // Booleano que indica si hay algun error en el valor de los parametros
   double balanceInicial; // Balance inicial del mercado, cuando ponemos este EA en marcha
  

int OnInit(){
   tiempoUltimaVelaProcesada = 0;
   balanceInicial = AccountBalance();
   errorParametros = (nivelLog>3);
   if (nivelLog > 0) Print("EA ", NOMBRE, " iniciado");
   if (errorParametros && nivelLog!=0) Print("Error en el valor de los parametros");
   return(INIT_SUCCEEDED);
}


void OnTick(){

   // Este EA esta diseñado para poder ser OpenPrice. Así que si no estamos en la apertura
   // de la vela (o existe algun error en los parametros), no hacemos nada
   if (Time[0]<=tiempoUltimaVelaProcesada || errorParametros) return;
   else tiempoUltimaVelaProcesada=Time[0];
   
   // Averiguamos el identificador de la posible operación que puede estar abierta con nuestro magic, o -1 si no hay ninguna
   int idOperacion = getOperacionAbierta(magicNumber);
   
   // Calculamos la media
   double EMALarga = iMA(NULL,0,periodoEMALarga,0,MODE_EMA,PRICE_CLOSE,0);
   
   // Si no hay ninguna operación abierta, metemos una
   if (idOperacion == -1) {
      
      // Calculamos los RSI necesarios
      double RSI0 = iRSI(NULL,0,periodoRSI,PRICE_CLOSE,0);
      double RSI1 = iRSI(NULL,0,periodoRSI,PRICE_CLOSE,1);
      double RSI2 = iRSI(NULL,0,periodoRSI,PRICE_CLOSE,2);
      
      // Calculamos si estamos saliendo de alguna zona extrema
      bool saliendoDeSobreCompra = (RSI2 >= 50+fronteraRSI && RSI1 < 50+fronteraRSI && RSI0 < 50+fronteraRSI);
      bool saliendoDeSobreVenta = (RSI2 <= 50-fronteraRSI && RSI1 > 50-fronteraRSI && RSI0 > 50-fronteraRSI);
      
      // Calculamos el lotaje segun nuestra gestión monetaria. La gestión monetaria será que nuestro lotaje
      // será proporcional a lo que ha subido o bajado el balance inicial. Para calcularlo, hacemos regla de 3
      double balanceActual = balanceInicial + getNetProfitTotal(magicNumber);
      double lotajeActual = lotajeInicial * (balanceActual/balanceInicial);
      lotajeActual = redondearLotaje(lotajeActual); // No cualquier lotaje es válido, así que lo aproximamos al válido más cercano
      
      // Entramos si se dan las condiciones
      if (saliendoDeSobreCompra && Bid>EMALarga){
         if (nivelLog>=3) Print("BalanceCalculado=", balanceActual, "|LotajeActual=", lotajeActual);
         idOperacion = OrderSend(NULL,OP_SELL,lotajeActual,Bid,slippageMaximo,0,EMALarga,"",magicNumber);
      }
      if (saliendoDeSobreVenta && Ask<EMALarga){
         if (nivelLog>=3) Print("BalanceCalculado=", balanceActual, "|LotajeActual=", lotajeActual);
         idOperacion = OrderSend(NULL,OP_BUY,lotajeActual,Ask,slippageMaximo,0,EMALarga,"",magicNumber);
      }
         
   }
   
   // Si hay alguna operacion viva, modificamos su TP para que siga puesto en la EMALarga
   else {      
      // Modificamos el TP para adaptarlo a la EMA
      bool exito = OrderSelect(idOperacion,SELECT_BY_TICKET);
      if (exito) OrderModify(idOperacion,0,0,EMALarga,0);      
   }

} // Fin "onTick()"





/**************************************************************************************************************
********************************* FUNCIONES *******************************************************************
***************************************************************************************************************/

// Selecciona la primera operacion abierta con un determinado magic number,
// y mete sus ids en un array.
// Parámetro: magic number requerido
// Retorno: identificador de la operacion abierta encontrada con ese magic number, o -1 si no hay ninguna abierta con ese magic
int getOperacionAbierta(int magicNumber) { 
   int total=OrdersTotal(); // Órdenes abiertas totales actualmente (a mercado y pendientes)
   int resultado = -1;

   // Vamos recorriendo todas las operaciones abiertas. Por cada una, comprobamos
   // si tiene el magic number requerido. Si es así, finalizamos el bucle
   for(int i=0;i<total && resultado==-1;i++) {
      bool exito = OrderSelect(i,SELECT_BY_POS); 
      if(exito && OrderMagicNumber() == magicNumber) resultado=OrderTicket(); // La hemos encontrado
   }
   
   return(resultado);
}



// Calcula el net profit de todas las operaciones cerradas con un determinado magic number
// Parámetro: magicNumber
// Devuelve el net profit total de todas las operaciones cerradas con ese magic
double getNetProfitTotal(int magicNumberLocal) {

   int total=OrdersHistoryTotal(); // Número de órdenes cerradas totales de nuestra cuenta
   
   // Calculamos la suma del beneficio de todas ellas que tengan nuestro magic number
   double ganancia = 0;
   for (int i=0; i<total; i++) {
      bool exito = OrderSelect(i,SELECT_BY_POS,MODE_HISTORY); // Seleccionamos cada una de las operaciones del array de operaciones cerradas
      if (exito && OrderMagicNumber() == magicNumberLocal) ganancia = ganancia + OrderProfit() + OrderCommission() + OrderSwap();
   }   
     
   return(ganancia);
}


// Redondea el lotaje al lotaje válido más próximo, según el lotaje mínimo, máximo y paso permitido en ese mercado.
// Ej: EURUSD con un broker tiene lotMin=0.5, paso=0.2, lotMax=10. 0.86 lo redondearía a 0.9
// Nota: al redondear el lotaje, puede que el lotaje final tenga más decimales de los que admite el broker. Esto no es
// problema porque MT4 suprimirá todos los decimales que sobren.
// Parámetro: el lotaje que queremos redondear
// Retorno: el lotaje redondeado al lotaje válido más próximo
double redondearLotaje(double lotajeReal) {
   double lotajeMinimo = MarketInfo(Symbol(),MODE_MINLOT);
   double lotajePaso = MarketInfo(Symbol(),MODE_LOTSTEP);
   double lotajeMaximo = MarketInfo(Symbol(),MODE_MAXLOT);
   
   // Devolvemos lotaje máximo o minimo permitido si el lotajeReal supera algún límite
   if (lotajeReal <= lotajeMinimo) return(lotajeMinimo);
   if (lotajeReal >= lotajeMaximo) return(lotajeMaximo);
   
   // Vamos añadiendo lotajePaso hasta superar el lotajeReal
   double lotajeRedondeadoSuperior = lotajeMinimo;
   while (lotajeRedondeadoSuperior < lotajeReal) {
      lotajeRedondeadoSuperior = lotajeRedondeadoSuperior + lotajePaso;
   }
   
   // Ahora vemos si está más cerca del lotajeReal el redondeo superior o el inferior
   double lotajeRedondeadoInferior = lotajeRedondeadoSuperior - lotajePaso;
   double distanciaSuperior = lotajeRedondeadoSuperior - lotajeReal;
   double distanciaInferior = lotajeReal - lotajeRedondeadoInferior;
   if (distanciaInferior <= distanciaSuperior) return(lotajeRedondeadoInferior);
   else return(lotajeRedondeadoSuperior);
   
}

