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

#include <errorHandler.mqh>
#include <macdUtils.mqh>

extern uint slow_ema_period = 12;
extern uint fast_ema_period = 26;
extern uint signal_line_period = 9;
extern double lotage = 0.01;
// Threshold (in absolute value) of the crossing between the signal line and the MACD to be considered a buy or sell signal.
extern double cross_signal_ema_shift = 0.0001; 
extern uint log_level = 0;
extern int magic_number = DATE;

//Global variables for the expert advisor

bool wrong_parameters = false;
datetime last_candle_process_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   wrong_parameters = checkInitialParameters(slow_ema_period, fast_ema_period, signal_line_period, log_level);
   last_candle_process_time = 0;
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    if (wrong_parameters) {
      if (log_level > 0) { Print("Wrong parameters, the EA won't execute until the parameter error is fixed"); }
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
    double signalCurrent=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);







//---
   
  }
//+------------------------------------------------------------------+
