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
input uint adxPeriod = 14;
input uint adxLevel = 25;
//Percentage of the account balance to be used in each operation (0.01 = 1%)
input double riskParameter = 0.1;

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
    double adx = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MAIN, 1);

    
    //First we check if we have an open position, in case we have one, we check if It's Long or short position to update correctly each OrderId
    if (id_long_operation != -1 || id_short_operation != -1) {
       //We put back the id_long_operation to -1 to let new positions to be opened
        if (id_long_operation != -1) {
          bool order_closed = handleOpenPosition(id_long_operation, counter_trend_candles, log_pointer);
          if (order_closed) {
              id_long_operation = -1;
          }
        }
        if (id_short_operation != -1) {
          bool order_closed = handleOpenPosition(id_short_operation, counter_trend_candles, log_pointer);
          if (order_closed) {
              id_short_operation = -1;
          }
        }
      //If we don't have an open position, we check if we have to open one
    } 

    bool go_long = (id_long_operation == -1) && (macd > 0) && (macd > signal_current + MathAbs(cross_signal_macd_shift)) && !checkCloseOperation(counter_trend_candles, OP_BUY);
    bool go_short = (id_short_operation == -1) && (macd < 0) && (macd < signal_current - MathAbs(cross_signal_macd_shift)) && !checkCloseOperation(counter_trend_candles, OP_SELL);
    double actual_balance = initalBalance + eaProfit(magic_number, log_pointer);
    

    _log.debug("MACD: " + macd + ", signal " + signal_current + ", go_long: " + go_long + ", go_short: " + go_short);
    if (go_long &&  (adx > adxLevel) ) {
      //We will go long in case we have the MACD above the signal line and tha MACD is possitive (above 0)
      double valid_lotage = getLotSize(riskParameter, actual_balance, Ask, log_pointer);
      _log.debug("We open a long position");
      id_long_operation = OrderSend(Symbol(), OP_BUY, valid_lotage, Ask, slippage, 0, 0, "", magic_number);
      int check=GetLastError();
      if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
    }

    if (go_short && (adx > adxLevel)) {
      //We will go short in case we have the MACD below the signal line and tha MACD is negative (below 0)
      double valid_lotage = getLotSize(riskParameter, actual_balance, Bid, log_pointer);
      _log.debug("We open a short position");
      id_short_operation = OrderSend(Symbol(), OP_SELL, valid_lotage, Bid, slippage, 0, 0, "", magic_number);
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

