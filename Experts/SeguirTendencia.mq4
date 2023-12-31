//+------------------------------------------------------------------+
//|                                                   Hola mundo.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//--- input parameters
extern double lotes = 0.1;
extern int stopLoss = 1000;
extern int takeProfit = 1000;

int idOperacion = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   MathSrand(TimeLocal());
   Print("Iniciado robot");
   int numeroAleatorio = MathRand();
   
   if (numeroAleatorio % 2 == 0 ) {
      double SLCompra = Ask-stopLoss*Point;
      double TPCompra = Ask+takeProfit*Point;
      idOperacion = OrderSend(Symbol(), OP_BUY, lotes, Ask, 0, SLCompra, TPCompra);
   } else  {
      double SLVenta = Bid+stopLoss*Point;
      double TPVenta = Bid-takeProfit*Point;
      idOperacion = OrderSend(Symbol(), OP_SELL, lotes, Bid, 0, SLVenta, TPVenta);
   
   }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
Print("Borramos Robot");
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   double beneficioUltimaOperacion;
   int tipoUltimaOperacion;
   bool isOperacionAbierta;
   if (idOperacion == -1 ) { isOperacionAbierta = false;}
   else {
      OrderSelect(idOperacion, SELECT_BY_TICKET);
      if (OrderCloseTime() == 0) { isOperacionAbierta = true; }
      else {
         isOperacionAbierta = false;
         beneficioUltimaOperacion = OrderProfit();
         tipoUltimaOperacion = OrderType();
      }
   }
   
   if (!isOperacionAbierta){
      if ((beneficioUltimaOperacion > 0 && tipoUltimaOperacion == OP_BUY)
      || beneficioUltimaOperacion < 0 && tipoUltimaOperacion == OP_SELL ) {
         double SLCompra = Ask-stopLoss*Point;
         double TPCompra = Ask+takeProfit*Point;
         idOperacion = OrderSend(Symbol(), OP_BUY, lotes, Ask, 0, SLCompra, TPCompra);
         
      } else {
         double SLVenta = Bid+stopLoss*Point;
         double TPVenta = Bid-takeProfit*Point;
         idOperacion = OrderSend(Symbol(), OP_SELL, lotes, Bid, 0, SLVenta, TPVenta);
      }
   }
   
  }
//+------------------------------------------------------------------+
