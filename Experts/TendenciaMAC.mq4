/*
Sistema TendenciaMAC (entramos a favor de la tendencia en su receso, marcado por una EMA). 

EA de MT4 que implementa en open price un sistema tendencial intradiario que hace lo siguiente:
- Entramos, por orden limitada, en el receso de una tendencia, marcada por una EMA20 o similar. 
- Salimos (por TP) en el máximo/mínimo ciego alcanzado por la tendencia.
- Salimos (por SL) en la EMA60 o similar.
- Salimos si la tendencia de entrada ha cambiado
- Salimos si llegamos al fin de día
- Detectamos que tenemos una tendencia porque el MACD esta por encima, en valor absoluto, de un determinado umbral.

Gestión monetaria: 
- Cada operación arriesga un lotaje que es proporcional al balance máximo que ha llegado a tener la cuenta
- El lotaje inicial se establece como parámetro externo
*/

#property strict

#define COPYRIGHT "Dr. CarlosGrima.com"
#define LINK      "http://www.carlosgrima.com"
#define VERSION   "1.0"
#define FECHA     20180403
#define NOMBRE    "TendenciaMAC"

#property copyright COPYRIGHT
#property link      LINK
#property version   VERSION

#include <miBiblioteca.mqh> // Esta linea se sustituye por todo lo que hay en el archivo "miBiblioteca.mqh", que se pone en /MQL4/Include

// Parámetros optimizables del EA

   // Parámetros de la media corta y larga
   extern uint periodoEMARapida = 20;
   extern uint periodoEMALenta = 50;
   // Umbral (en valor absoluto) del MACD(12,26) a partir del cual se condiera que estamos en tendencia
   extern double umbralMACD = 0.0001; 
   
// Parámetros del EA que NO se deberían optimizar

   // Lotaje inicial de las operaciones. Se va incrementando segun vamos ganando dinero, pero no se decrementa al perder
   extern double lotajeInicial = 0.1;
   extern int magicNumber = FECHA; 
   // Sólo metemos operaciones dentro del siguiente horario
   extern uint horaInicioSesion=9;
   extern uint horaFinSesion = 22;
   // Deslizamiento maximo para meter una nueva operacion
   extern uint slippageMaximo = 0;
   // nivelLog. Indica la cantidad de informacion que se imprimira en el log. 
   // 0: nada. 1: sólo errores. 2: info normal. 3: info completa (puede generarse info en cada tick!!). Poner 0 en backtest. 
   extern uint nivelLog = 3; 

// Variables globales
   datetime tiempoUltimaVelaProcesada; // Tiempo de apertura de la ultima vela procesada (para implementar "open price")
   bool errorParametros; // Booleano que indica si hay algun error en el valor de los parametros
   double lotaje; // Lotaje actual, segun la gestión monetaria. Se va incrementando segun ganamos, pero no segun perdemos
   double balanceInicial; // Balance inicial de la cuenta cuando iniciamos este EA
   

int OnInit(){
   lotaje = lotajeInicial;
   tiempoUltimaVelaProcesada = 0;
   balanceInicial = AccountBalance();
   if (!IsTesting() && !IsOptimization()) cargarVariables(); // Por si se reinicio el EA inesperadamente
   errorParametros = (periodoEMARapida > periodoEMALenta || nivelLog>3 || umbralMACD<0);
   if (errorParametros && nivelLog!=0) Print("Error en el valor de los parametros");
   return(INIT_SUCCEEDED);
}


void OnTick(){

   // Este EA esta diseñado para poder ser OpenPrice. Así que si no estamos en la apertura
   // de la vela (o existe algun error en los parametros), no hacemos nada
   if (Time[0]<=tiempoUltimaVelaProcesada || errorParametros) return;
   else tiempoUltimaVelaProcesada=Time[0];

   // Calculamos los indicadores necesarios, ambos de la vela anterior (que ya está cerrada)
   double emaRapida = iMA(NULL, 0, periodoEMARapida, 0, MODE_EMA,PRICE_CLOSE, 1);
   double emaLenta = iMA(NULL, 0, periodoEMALenta, 0, MODE_EMA,PRICE_CLOSE, 1);
   double macd = iMACD(NULL,0,12,26,1,PRICE_CLOSE,MODE_MAIN,1);
   
   // Aplicamos el filtro horario. Si no estamos en su rango, no abrimos nuevas y cerramos las abiertas
   bool enRangoHorario = true; // Nos dirá si estamos dentro del rango horario válido para operar
   uint ahora = TimeHour(Time[0]); // Obtenemos la hora de apertura de la vela actual (no los minutos ni segundos)
   if (horaInicioSesion<horaFinSesion && (ahora<horaInicioSesion || ahora>horaFinSesion)) enRangoHorario=false;
   if (horaInicioSesion>horaFinSesion && ahora>horaFinSesion && ahora<horaInicioSesion) enRangoHorario=false;
  
   // Averiguamos si tenemos una operacion abierta o pendiente
   int idOperacion = getOperacionAbierta(magicNumber); 
   
   // Si hay alguna operación abierta o pendiente, modificamos sus datos (SL,TP y precio de apertura) si 
   // seguimos en la misma tendencia. Si no, se liquida.
   if (idOperacion!=-1) {
      OrderSelect(idOperacion,SELECT_BY_TICKET);
      int tipoOrden = OrderType();      
      double takeProfit,precioApertura,stopLoss; // Datos de la operacion
      
      // Si la operación ya está abierta y es BUY
      if (tipoOrden==OP_BUY) {
         if (macd<0 || !enRangoHorario) OrderClose(idOperacion,lotaje,Bid,slippageMaximo);
         else {
            takeProfit=OrderTakeProfit(); // Si la operación está abierta, el TP permanece igual
            precioApertura=OrderOpenPrice(); // Si la operacion esta abierta, el precio de apertura no se modifica
            stopLoss=emaLenta;
            OrderModify(idOperacion,precioApertura,stopLoss,takeProfit,0); 
         }
      }
      
      // Si la operación ya está abierta y es SELL
      if (tipoOrden==OP_SELL) {
         if (macd>0 || !enRangoHorario) OrderClose(idOperacion,lotaje,Ask,slippageMaximo);
         else {
            takeProfit=OrderTakeProfit(); // Si la operación está abierta, el TP permanece igual
            precioApertura=OrderOpenPrice(); // Si la operacion esta abierta, el precio de apertura no se modifica
            stopLoss=emaLenta;
            OrderModify(idOperacion,precioApertura,stopLoss,takeProfit,0);
         }
      }
      
      // Si la operacion aun es una limitada BUY pendiente, recalculamos su TP, SL y precio de apertura
      if (tipoOrden==OP_BUYLIMIT) {
         if (macd<0 || !enRangoHorario) OrderDelete(idOperacion);
         else {
            takeProfit = getMaximoCiegoTendencia();
            precioApertura=emaRapida;
            stopLoss=emaLenta;
            OrderModify(idOperacion,precioApertura,stopLoss,takeProfit,0);
         }
      }
      
      // Si la operacion aun es una limitada SELL pendiente, recalculamos su TP, SL y precio de apertura
      if (tipoOrden==OP_SELLLIMIT) {
         if (macd>0 || !enRangoHorario) OrderDelete(idOperacion);
         else {
            takeProfit = getMinimoCiegoTendencia();
            precioApertura=emaRapida;
            stopLoss=emaLenta;
            OrderModify(idOperacion,precioApertura,stopLoss,takeProfit,0);
         }
      }          
         
      
   }
   
   // Si no hay ninguna operación abierta
   else {
   
      // Calculamos el lotaje segun nuestra gestión monetaria. El lotaje sube cuando el balance crece,
      // pero no baja cuando el balance decrece. 
      double balance = balanceInicial + getNetProfitTotal(magicNumber);
      double lotajeActual = redondearLotaje((balance*lotajeInicial)/balanceInicial);
      if (lotajeActual > lotaje) lotaje = lotajeActual;
   
      // Metemos una operación pendiente larga
      if (enRangoHorario && macd>0 && MathAbs(macd)>=umbralMACD && emaRapida>emaLenta && getMaximoCiegoTendencia()>Ask) {
         double precioApertura=emaRapida;
         double stopLoss=emaLenta;
         double takeProfit=getMaximoCiegoTendencia();
         uint distanciaSL=getPuntos(precioApertura-stopLoss);
         uint distanciaTP=getPuntos(takeProfit-precioApertura);         
         introducirNuevaOperacion(lotaje, OP_BUYLIMIT, precioApertura, distanciaSL, distanciaTP);
      }
      
      // Metemos una operación pendiente corta
      if (enRangoHorario && macd<0 && MathAbs(macd)>=umbralMACD && emaRapida<emaLenta && getMinimoCiegoTendencia()<Bid) {
         double precioApertura=emaRapida;
         double stopLoss=emaLenta;
         double takeProfit=getMinimoCiegoTendencia();
         uint distanciaSL=getPuntos(stopLoss-precioApertura);
         uint distanciaTP=getPuntos(precioApertura-takeProfit);         
         introducirNuevaOperacion(lotaje, OP_SELLLIMIT, precioApertura, distanciaSL, distanciaTP);
      }
   
   }
   
   if (!IsTesting() && !IsOptimization()) salvarVariables(); // Por si se reinicia el EA inesperadamente
    
} // Fin "onTick()"


