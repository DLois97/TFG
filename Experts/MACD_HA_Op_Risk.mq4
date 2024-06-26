//+------------------------------------------------------------------+
//|                                              MACDHeinkenAshi.mq4 |
//|                                  Copyright 2023, Daniel Lois Nuevo. |
//|                                            |
//+------------------------------------------------------------------+
#define VERSION   "1.0"
#define DATE     20230810
#define NAME    "MACDHeinkenAshi"

#property copyright "Copyright 2023, Daniel Lois Nuevo"
#property link      "https://github.com/DLois97"
#property version   VERSION
#property strict

#include <Logger.mqh>
#include <OperationUtils.mqh>
#include <stderror.mqh>
#include <stdlib.mqh>

input uint slow_ema_period = 26;
input uint fast_ema_period = 12;
input uint signal_line_period = 9;
input uint counter_trend_candles = 3;
input uint pipsDistance = 25000;
//Relationship between SL and TP (2.0 = TP - Price distance at 2 x pips distance of the SL - Price)
input double operationRisk = 2.00;
//Percentage of the account balance to be used in each operation (0.01 = 1%)
input double lotage = 0.1;

// Threshold (in absolute value) of the crossing between the signal line and the MACD to be considered a buy or sell signal.
input double cross_signal_macd_shift = 0.0001; 
input uint log_level = 0;
input int magic_number = DATE;
input int slippage = 3;

//Global variables for the expert advisor

bool wrong_parameters = false;
datetime last_candle_process_time;
Logger _log;
Logger *log_pointer;
int id_long_operation;
int id_short_operation;
double initalBalance;


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
  initalBalance = AccountBalance();
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //In case we have wrong parameters, the EA will not execute
    _log.info("We are in the OnTick function");
    if (wrong_parameters) {
      _log.error("Wrong parameters, the EA won't execute until the parameter error is fixed"); 
      return;
    }

    //Our EA will only work once by candle, so we check if the last candle has finished
    //We check if the last candle has finished
    if (Time[0]<=last_candle_process_time) {
      return;
    } else {
      last_candle_process_time = Time[0];
    }

    //We get the id of the open positions by our EA
    id_long_operation = getOpenPosition(magic_number, log_pointer, true);
    id_short_operation = getOpenPosition(magic_number, log_pointer, false);

    //We get the MACD and signal values for the last candle
    double macd = iMACD(NULL, 0, fast_ema_period, slow_ema_period, signal_line_period, PRICE_CLOSE, MODE_MAIN, 1);
    double signal_current=iMACD(NULL,0,fast_ema_period, slow_ema_period, signal_line_period, PRICE_CLOSE, MODE_SIGNAL , 1);


    bool go_long = (id_long_operation == -1) && (macd > 0) && (macd > signal_current + MathAbs(cross_signal_macd_shift)) && !checkCloseOperation(counter_trend_candles, OP_BUY);
    bool go_short = (id_short_operation == -1) && (macd < 0) && (macd < signal_current - MathAbs(cross_signal_macd_shift)) && !checkCloseOperation(counter_trend_candles, OP_SELL);
    double actual_balance = initalBalance + eaProfit(magic_number, log_pointer);
    

    _log.debug("MACD: " + macd + ", signal " + signal_current + ", go_long: " + go_long + ", go_short: " + go_short);
    if (go_long) {
      //We will go long in case we have the MACD above the signal line and tha MACD is possitive (above 0)
      double valid_lotage = getLotSize(lotage, actual_balance, Ask, log_pointer);
      _log.debug("We open a long position");

      //We get the SL and TP for the short position
      double sl = Ask - pipsDistance * Point;
      double tp = Ask + operationRisk * pipsDistance * Point;

      id_long_operation = OrderSend(Symbol(), OP_BUY, valid_lotage, Ask, slippage, sl, tp, "", magic_number);
      int check=GetLastError();
      if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
    }

    if (go_short) {
      //We will go short in case we have the MACD below the signal line and tha MACD is negative (below 0)
      double valid_lotage = getLotSize(lotage, actual_balance, Bid, log_pointer);

      //We get the SL and TP for the short position
      double sl = Bid + pipsDistance * Point;
      double tp = Bid - operationRisk * pipsDistance * Point;
      _log.debug("We open a short position");
      id_short_operation = OrderSend(Symbol(), OP_SELL, valid_lotage, Bid, slippage, sl, tp, "", magic_number);
      int check=GetLastError();
      if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}

    }
    _log.info("Llegamos aqui");

    


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


    return false; 
}

