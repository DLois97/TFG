// EA de MT4 que compra sucesivamente siguiendo la estrategia Martingala. Cada vez que una operación acaba en pérdidas, se mete otra operación con el
// mismo SL y TP pero de doble lotaje que la anterior. Cuando finalmente una operación resulta ganadora, se reinicia el lotaje a su valor inicial.
// Todas las operaciones tienen el SL y TP a la misma distancia de la entrada.

#property strict

#define COPYRIGHT "Dr. CarlosGrima.com"
#define LINK      "http://www.carlosgrima.com"
#define VERSION   "2.0"
#define FECHA     20160904
#define NOMBRE    "Martingala"

#property copyright COPYRIGHT
#property link      LINK
#property version   VERSION

// Parámetros del EA
extern double lotes = 0.1; // Número de lotes en la operación inicial de cada ráfaga de operaciones
extern uint distanciaTPySL = 50; // Distancia en puntos básicos desde el precio de entrada hasta el SL o TP
extern uint magicNumber = FECHA; // Magic number. No optimizar
extern uint nivelLog = 2; // nivelLog. Indica la cantidad de informacion que se imprimira en el log. 0: nada. 1: info normal y errores. 2: info completa (puede generarse info en cada tick!!). Poner 0 en backtest. No optimizar
 
// Variables globales
int idOperacion = -1; // Identificador de la actual operación abierta. -1 significa que aún no hay ninguna
int multiplicador = 1; // En cada operación, meteremos un volumen de lotes*multiplicador. Al principio de cada secuencia es 1, y va duplicándose cada vez que perdemos
   
int OnInit() {

   // Por si hemos reiniciado el Metatrader4, intentamos cargar el multiplicador desde disco
   // y ver si tenemos alguna operación abierta (si no, ponemos -1 en idOperacion)
   cargarMultiplicador();
   idOperacion = getOperacionAbierta(magicNumber);
   if (nivelLog>0) {
      if (idOperacion==-1) Print("No hay ninguna operacion abierta con nuestro magic number");
      else Print ("Encontrada una operación abierta con nuestro magic. Identificador: ", idOperacion);
   }  
 
   return(INIT_SUCCEEDED);
}   
   
// Función especial que se ejecuta cada vez se produce un tick (es decir: un cambio de precio)   
void OnTick() {

   // Si acabamos de iniciar el programa o bien no funcionó la introducción de la última operación,
   // metemos una operación y acabamos
   if (idOperacion == -1) {
      idOperacion = introducirNuevaOperacion();
      return;
   }

   // Si la operacion no está abierta, actualizamos lotaje según si termino con beneficios o pérdidas 
   // e intentamos meter una nueva operación
   if (!isOperacionAbierta(idOperacion)) {
   
      // Actualizamos el multiplicador segun si fue ganadora o perdedora
      if (isOperacionGanadora(idOperacion)) multiplicador = 1; 
      else multiplicador = multiplicador * 2;
      
      // Lo guardamos en disco por si reiniciamos el Metatrader
      salvarMultiplicador();
      
      // Metemos la operación
      idOperacion = introducirNuevaOperacion(); // Si no funciona (ej: por slippage) devuelve -1
   }
 
}
 
// Introducimos una nueva operacion de compra predefinida. Lo intenta hasta que lo consigue
// Retorno: identificador de la nueva operacion metida o -1 si no se pudo meter por slippage o cualquier otro error
int introducirNuevaOperacion() {
   int idOperacion;
   double sl = NormalizeDouble(Ask-distanciaTPySL*Point, Digits);
   double tp = NormalizeDouble(Ask+distanciaTPySL*Point, Digits);
   idOperacion = OrderSend(Symbol(),OP_BUY,lotes*multiplicador,Ask,0,sl,tp,"",magicNumber);
   return(idOperacion);
}
 
 
// Comprueba si una operación cuyo id se proporciona está aún abierta
// Parámetro: identificador de la operación que devuelve OrderSend() cuando la orden se crea
// Retorno: true si la operación sigue abierta, false si está cerrada
// Precondición: el identificador de la operación existe
bool isOperacionAbierta(int idOperacion) { 
   bool resultado = false; // Contendrá el resultado
   // Seleccionamos la operacion
   OrderSelect(idOperacion, SELECT_BY_TICKET);       
   // Si la operación seleccionada tiene alguna fecha de cerrado, es que ya está efectivamente cerrada
   if (OrderCloseTime() == 0) resultado = true;
   return(resultado);
}

// Comprueba si una operación cuyo id se proporciona es ganadora o perdedora
// Parámetro: identificador de la operación que devuelve OrderSend() cuando la orden se crea
// Retorno: true si la operación es o ha sido ganadora, false si es o ha sido perdedora
// Precondición: el identificador de la operación existe
bool isOperacionGanadora(int idOperacion) { 
   bool resultado = false; 
   OrderSelect(idOperacion, SELECT_BY_TICKET);       
   if (OrderProfit() > 0) resultado = true;
   return(resultado);
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
   for(int i=0; i<total && resultado==-1; i++) {
      bool exito = OrderSelect(i, SELECT_BY_POS, MODE_TRADES); // Seleccionamos la operación por posicion en el array de operaciones abiertas/pendientes
      if(exito && OrderMagicNumber() == magicNumber) resultado=OrderTicket(); // La hemos encontrado
   }
   
   return(resultado);
}
   
  
// Carga la variable "multiplicador" desde el disco duro
// El nombre del fichero es <nombreEA><version>-Magic<magicNumber>.csv
void cargarMultiplicador() {
   string nombreFichero = NOMBRE + "v" + VERSION + "-Magic" + magicNumber + ".csv";
   int filehandle=FileOpen(nombreFichero,FILE_READ|FILE_CSV);
   if(filehandle!=INVALID_HANDLE) {
      multiplicador = FileReadNumber(filehandle);
      FileClose(filehandle);
      if (nivelLog>0) Print("Multiplicador actual (", multiplicador, ") recuperado del archivo ", nombreFichero);
   }
   else {
      if (nivelLog>0) Print("Fichero ", nombreFichero, " no se encuentra o no se puede abrir. Multiplicador será el inicial");
   }
}  
  
  
// Salva la variable "multiplicador" a disco duro por si el Metatrader se cierra
// El nombre del fichero es <nombreEA><version>-Magic<magicNumber>.csv
void salvarMultiplicador() {
   string nombreFichero = NOMBRE + "v" + VERSION + "-Magic" + magicNumber + ".csv";
   int filehandle=FileOpen(nombreFichero,FILE_WRITE|FILE_CSV);
   if(filehandle!=INVALID_HANDLE) {
      FileWrite(filehandle,multiplicador);
      FileClose(filehandle);
      if (nivelLog==2) Print("Variable multiplicador guardada en archivo ", nombreFichero);
     }
   else {
      if (nivelLog>0) Print("Apertura para escritura del fichero ", nombreFichero, " fallida. Error: ",GetLastError());
   }
}
