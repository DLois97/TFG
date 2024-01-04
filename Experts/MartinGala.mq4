//+------------------------------------------------------------------+
//|                                                   MartinGala.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
extern double lotes = 0.1;
extern int distanciaTPySL = 50;

int idOperacion = -1;
int multiplicador = 1;

int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if (idOperacion == -1) {
      idOperacion = introducirNuevaOperacion();
      return;
   }
   
   if (!isOperacionAbierta(idOperacion)) {
      if (isOperacionGanadora(idOperacion)) {multiplicador = 1;}
      else {multiplicador = multiplicador * 2;}
      
      idOperacion = introducirNuevaOperacion();
   }
   
  }
  
  int introducirNuevaOperacion() {
   int idOperacion;
   double sl = Ask-distanciaTPySL*Point;
   double tp = Ask+distanciaTPySL*Point;
   idOperacion = OrderSend(Symbol(), OP_BUY, lotes*multiplicador, Ask, 0 ,sl, tp);
   return(idOperacion);
  }
  
  bool isOperacionAbierta(int idOperacion) {
   bool result = false;
   OrderSelect(idOperacion, SELECT_BY_TICKET);
   if (OrderCloseTime() == 0){result = true;}
   return(result);
  }
  
  bool isOperacionGanadora(int idOperacion) {
   bool resultado = false;
   OrderSelect(idOperacion, SELECT_BY_TICKET);
   if (OrderProfit() > 0) { resultado = true;}
   return(resultado);
  }
//+------------------------------------------------------------------+
