// Algunas funciones comunes para usar en mis EAs

#property copyright "Dr. CarlosGrima.com"
#property link      "http://www.carlosgrima.com"
#property version   "1.0"

// Calculamos el máximo ciego de toda la tendencia alcista actual (es decir, de todas las velas anteriores (actual inclusive) en las cuales 
// el MACD permanezca positivo)
// Devuelve: máximo ciego (es decir, sin contar la mecha de la vela) en todas esas velas. -1 si las velas son bajistas (MACD<0)
double getMaximoCiegoTendencia() {
   double maximo = -1; 
   uint indiceVela = 0;
   // Mientras el MACD de una vela sea positivo, miramos a ver si su Open o su Close es mayor que el máximo
   // que tenemos hasta el momento actual
   while (iMACD(NULL,0,12,26,1,PRICE_CLOSE,MODE_MAIN,indiceVela)>0) {
      if (Open[indiceVela]>maximo) maximo = Open[indiceVela];
      if (Close[indiceVela]>maximo) maximo = Close[indiceVela];
      indiceVela++;
   }
   return(maximo);
}


// Calculamos el mínimo ciego de toda la tendencia bajista actual (es decir, de todas las velas anteriores (actual inclusive) en las cuales 
// el MACD permanezca negativo)
// Devuelve: mínimo ciego (es decir, sin contar la mecha de la vela) en todas esas velas. -1 si las velas son alcistas (MACD>0)
double getMinimoCiegoTendencia() {
   double minimo = -1; 
   uint indiceVela = 0;
   // Mientras el MACD de una vela sea negativo, miramos a ver si su Open o su Close es menor que el mínimo
   // que tenemos hasta el momento actual
   while (iMACD(NULL,0,12,26,1,PRICE_CLOSE,MODE_MAIN,indiceVela)<0) {
      if (Open[indiceVela]<minimo || minimo==-1) minimo = Open[indiceVela];
      if (Close[indiceVela]<minimo) minimo = Close[indiceVela];
      indiceVela++;
   }
   return(minimo);
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







// Convertimos un precio en puntos
// Parámetro: precio que se quiere convertir en puntos
// Retorno: puntos del precio (es decir: cantidad del último dígito)
// Precondición: precio >= 0
uint getPuntos (double precio) {
   if (precio<0) {
      if (nivelLog>=1) Print("ERROR: parametro negativo en funcion getPuntos()");
      precio=0;
   }
   return ((uint)(precio*pow(10,Digits)));
}





// Introducimos una nueva operacion de cualquier tipo. Si no se puede introducir la operación,
// espera varios ticks y segundos por si la operación realmente sí se metió, para que pueda aparecer en MT4
// antes de que onTick() se ejecute de nuevo
// Parámetros:
// - lotaje: lotaje, ya redondeado y valido
// - sentidoOperacion: puede ser OP_BUYLIMIT, OP_BUYSTOP, OP_BUY, OP_SELLLIMIT, OP_SELLSTOP o OP_SELL (constantes predefinidas)
// - precioApertura: el precio que queremos para la apertura. Si es OP_BUY debería ser Ask. Si es OP_SELL debería ser Bid
// - distanciaAlSL: distancia en puntos desde la apertura al SL. 0 significa sin SL
// - distanciaAlTP: distancia en puntos desde la apertura al TP. 0 significa sin TP
// Retorno: identificador de la nueva operacion metida, o -1 si falló
int introducirNuevaOperacion(double lotajeLocal, int tipoOperacion, double precioApertura, uint distanciaAlSL, uint distanciaAlTP) {
   int idOperacionLocal;
   double SLLocal=0, TPLocal=0; // SL y TP que pondremos en la nueva operación
   
   // Normalizamos el precio de apertura, por si no lo está en el caso de ser una operacion limitada
   precioApertura = NormalizeDouble(precioApertura,Digits);
   
   // Calculamos SL y el TP
   if (tipoOperacion == OP_BUYLIMIT || tipoOperacion == OP_BUYSTOP || tipoOperacion == OP_BUY) {
      if (distanciaAlSL>0) SLLocal = precioApertura-distanciaAlSL*Point;
      if (distanciaAlTP>0) TPLocal = precioApertura+distanciaAlTP*Point;
   }
   else {
      if (distanciaAlSL>0) SLLocal = precioApertura+distanciaAlSL*Point;
      if (distanciaAlTP>0) TPLocal = precioApertura-distanciaAlTP*Point;
   }
   
   // Normalizamos
   SLLocal = NormalizeDouble(SLLocal,Digits);
   TPLocal = NormalizeDouble(TPLocal,Digits);
   
   // Intentamos introducir la operación
   idOperacionLocal = OrderSend(Symbol(),tipoOperacion,lotajeLocal,precioApertura,slippageMaximo,SLLocal,TPLocal,"",magicNumber);
   
   // Si ha ocurrido aparentemente algun error, es posible que la operación realmente haya entrado
   // (por ejemplo, porque se cortó la conexión y el broker no pudo devolvernos el identificador de la operación)
   // En este caso, vamos a esperar varios ticks y segundos para dar oportunidad a que la operación 
   // aparezca en el Metatrader 4 y por lo tanto la podamos recuperar en la siguiente ejecución de onTick()
   if (idOperacionLocal == -1 && !IsTesting() && !IsOptimization()) {
      for (int i=0; i<5; i++) { // Vamos a esperar a que lleguen 5 ticks. Si no hay conexión, no llegarán
         // Esperamos a que llegue un nuevo tick. Lo comprobamos cada 2 segundos, para no saturar el ordenador
         while (RefreshRates()==false) Sleep(2000);
         Sleep(1000); // Esperamos 1 segundo en este tick
      }
   }
   
   return(idOperacionLocal);
   
} // Fin introducirNuevaOperacion()




// Carga las variables globales necesarias desde el disco duro
// El nombre del fichero es <nombreEA><version>-Magic<magicNumber>.csv
void cargarVariables() {
   string nombreFichero = NOMBRE + "v" + VERSION + "-Magic" + magicNumber + ".csv";
   int filehandle=FileOpen(nombreFichero,FILE_READ|FILE_CSV);
   if(filehandle!=INVALID_HANDLE) {
      tiempoUltimaVelaProcesada = FileReadDatetime(filehandle);
      lotaje = FileReadNumber(filehandle);
      balanceInicial = FileReadNumber(filehandle);
      FileClose(filehandle);
      if (nivelLog>0) 
         Print("Variables globales recuperadas del archivo ", nombreFichero, ". ",
         "|tiempoUltimaVelaProcesada=", tiempoUltimaVelaProcesada,
         "|lotaje=", lotaje,
         "|balanceInicial=", balanceInicial);
   }
   else {
      if (nivelLog>0) Print("Fichero ", nombreFichero, " no se encuentra o no se puede abrir. Variables por defecto");
   }
}  
  
 
// Salva las variables globales necesarias a disco duro por si el Metatrader se cierra
// El nombre del fichero es <nombreEA><version>-Magic<magicNumber>.csv
void salvarVariables() {
   string nombreFichero = NOMBRE + "v" + VERSION + "-Magic" + magicNumber + ".csv";
   int filehandle=FileOpen(nombreFichero,FILE_WRITE|FILE_CSV);
   if(filehandle!=INVALID_HANDLE) {
      FileWrite(filehandle,tiempoUltimaVelaProcesada);
      FileWrite(filehandle,lotaje);
      FileWrite(filehandle,balanceInicial);
      FileClose(filehandle);
      if (nivelLog==3) 
         Print("Variables globales guardadas en archivo ", nombreFichero, ". ",
         "|tiempoUltimaVelaProcesada=", tiempoUltimaVelaProcesada,
         "|lotaje=", lotaje,
         "|balanceInicial=", balanceInicial);
   }
   else {
      if (nivelLog>0) Print("Apertura para escritura del fichero ", nombreFichero, " fallida. Error: ",GetLastError());
   }
}
