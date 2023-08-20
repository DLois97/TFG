//+------------------------------------------------------------------+
//|                                              MACDHeinkenAshi.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define VERSION   "1.0"
#define DATE     20230810
#define NAME    "MACDHeinkenAshi"

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   VERSION
#property strict

#include <Logger.mqh>
#include <MACDUtils.mqh>
#include <OperationUtils.mqh>

extern uint slow_ema_period = 26;
extern uint fast_ema_period = 12;
extern uint signal_line_period = 9;
extern double lotage = 0.01;
// Threshold (in absolute value) of the crossing between the signal line and the MACD to be considered a buy or sell signal.
extern double cross_signal_macd_shift = 0.0001; 
extern uint log_level = 0;
extern int magic_number = DATE;

//Global variables for the expert advisor

bool wrong_parameters = false;
datetime last_candle_process_time;
Logger _log;
Logger *log_pointer;
int idOperation;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  _log = Logger(log_level);
  log_pointer = &_log;
  wrong_parameters = checkInitialParameters(slow_ema_period, fast_ema_period, signal_line_period, log_level);
  last_candle_process_time = 0;
  idOperation = getOpenPosition(magic_number, log_pointer);
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    if (wrong_parameters) {
      _log.error("Wrong parameters, the EA won't execute until the parameter error is fixed"); 
      return;
    }
    //We check if the last candle has finished
    if (Time[0]<=last_candle_process_time) {
      return;
    } else {
      last_candle_process_time = Time[0];
    }

    //We get the MACD and signal values for the last candle
    double macd = iMACD(NULL, 0, fast_ema_period, slow_ema_period, signal_line_period, PRICE_CLOSE, MODE_MAIN, 1);
    double signalCurrent=iMACD(NULL,0,fast_ema_period, slow_ema_period, signal_line_period, PRICE_CLOSE, MODE_SIGNAL , 1);

    
    if (idOperation != -1) {
      bool orderSelected = OrderSelect(idOperation, SELECT_BY_TICKET);
      bool orderClosed = false;
      //If we have an open position, we check if we have to close it
      if (orderSelected) {
         if (OrderType() == OP_BUY) {
           bool closeLong = (macd < signalCurrent - MathAbs(cross_signal_macd_shift));
           if (closeLong) {
             _log.debug("We want to close a long position");
             orderClosed = closePosition(idOperation, log_pointer);
           }
         } else if (OrderType() == OP_SELL){
           bool closeShort = (macd > signalCurrent + MathAbs(cross_signal_macd_shift))  ;
           if (closeShort) {
            _log.debug("We want to close a short position");
             orderClosed = closePosition(idOperation, log_pointer);
           }
         }
      }
      //We put back the idOperation to -1
      if (orderClosed) {
         idOperation = -1;
      }
      //If we don't have an open position, we check if we have to open one
    } else {
      _log.debug("We don´t have open operation");
      bool goLong = (macd > 0) && (macd > signalCurrent + MathAbs(cross_signal_macd_shift));
      bool goShort = (macd < 0) && (macd < signalCurrent - MathAbs(cross_signal_macd_shift));
      _log.debug("MACD: " + macd + ", signal " + signalCurrent + ", goLong: " + goLong + ", goShort: " + goShort);
      if (goLong) {
         _log.debug("We open a long position");
        idOperation = OrderSend(Symbol(), OP_BUY, lotage, Ask, 0, 0, 0, "", magic_number);//openPosition(OP_BUY, lotage, magic_number, log_pointer);
      } else if (goShort) {
         _log.debug("We open a short position");
        idOperation = OrderSend(Symbol(), OP_SELL, lotage, Bid, 0, 0, 0, "", magic_number);//idOperation = openPosition(OP_SELL, lotage, magic_number, log_pointer);
      }

    }


//---
   
  }
//+------------------------------------------------------------------+

bool checkInitialParameters(uint s_ema_period, uint f_ema_period, uint slp, uint log_lvl){

    if (log_lvl>3) {
        _log.error("(PARAMETERS) The log level cannot be bigger than 3");
        return true;
    }

    if (f_ema_period > s_ema_period) {
        _log.error("(PARAMETERS) The fast EMA period cannot be bigger than the slow EMA period");
        return true;
    } 

    if (slp < 0) {
        _log.error("(PARAMETERS) The signal line period cannot be negative");
        return true;
    }

    return false; 
}