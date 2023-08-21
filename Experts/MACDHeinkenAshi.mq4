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
#include <HeikenAshiUtils.mqh>

extern uint slow_ema_period = 26;
extern uint fast_ema_period = 12;
extern uint signal_line_period = 9;
extern uint counter_trend_candles = 3;
//Percentage of the account balance to be used in each operation (0.01 = 1%)
extern double riskParameter = 0.01;

// Threshold (in absolute value) of the crossing between the signal line and the MACD to be considered a buy or sell signal.
extern double cross_signal_macd_shift = 0.0001; 
extern uint log_level = 0;
extern int magic_number = DATE;

//Global variables for the expert advisor

bool wrong_parameters = false;
datetime last_candle_process_time;
Logger _log;
Logger *log_pointer;
int id_operation;
double lotage = 0.01;
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
    id_operation = getOpenPosition(magic_number, log_pointer);
    //We get the MACD and signal values for the last candle
    double macd = iMACD(NULL, 0, fast_ema_period, slow_ema_period, signal_line_period, PRICE_CLOSE, MODE_MAIN, 1);
    double signal_current=iMACD(NULL,0,fast_ema_period, slow_ema_period, signal_line_period, PRICE_CLOSE, MODE_SIGNAL , 1);

    
    if (id_operation != -1) {
      bool order_selected = OrderSelect(id_operation, SELECT_BY_TICKET);
      bool order_closed = false;
      //If we have an open position, we check if we have to close it
      //We will close the long or short position in case we found X Heiken Ashi candles in the opposite direction
      if (order_selected) {
        if (OrderType() == OP_BUY) {
          bool close_long = checkCloseOperation(counter_trend_candles, OP_BUY);
          if (close_long) {
            _log.debug("We want to close a long position");
            order_closed = closePosition(id_operation, log_pointer);
          }
        } else if (OrderType() == OP_SELL){
          bool close_short = checkCloseOperation(counter_trend_candles, OP_SELL);
          if (close_short) {
          _log.debug("We want to close a short position");
            order_closed = closePosition(id_operation, log_pointer);
          }
        }
      }
      //We put back the id_operation to -1 to let new positions to be opened
      if (order_closed) {
         id_operation = -1;
      }
      //If we don't have an open position, we check if we have to open one
    } else {
      _log.debug("We don´t have open operation");
      bool go_long = (macd > 0) && (macd > signal_current + MathAbs(cross_signal_macd_shift));
      bool go_short = (macd < 0) && (macd < signal_current - MathAbs(cross_signal_macd_shift));
      double actual_balance = initalBalance + eaProfit(magic_number, log_pointer);
      

      _log.debug("MACD: " + macd + ", signal " + signal_current + ", go_long: " + go_long + ", go_short: " + go_short);
      if (go_long) {
        //We will go long in case we have the MACD above the signal line and tha MACD is possitive (above 0)
        double valid_lotage = getLotSize(riskParameter, actual_balance, Ask, log_pointer);
        _log.debug("We open a long position");
        id_operation = OrderSend(Symbol(), OP_BUY, valid_lotage, Ask, 0, 0, 0, "", magic_number);//openPosition(OP_BUY, lotage, magic_number, log_pointer);
      } else if (go_short) {
        //We will go short in case we have the MACD below the signal line and tha MACD is negative (below 0)
        double valid_lotage = getLotSize(riskParameter, actual_balance, Bid, log_pointer);
        _log.debug("We open a short position");
        id_operation = OrderSend(Symbol(), OP_SELL, valid_lotage, Bid, 0, 0, 0, "", magic_number);//id_operation = openPosition(OP_SELL, lotage, magic_number, log_pointer);
      }
      _log.info("Llegamos aqui");

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

bool checkCloseOperation(int number_of_candles, int operation_type) {
  generateHeikenAshiValues();
  for (int i = 0; i < number_of_candles; i++) {
    _log.debug("We are checking the candle number " + i);
    //We get the open and close values for the Heiken Ashi candles we don't care about the high and low values because we are not going to use them
    double openHA =HAOpenBuffer[i];
    double closeHA = HACloseBuffer[i];
    _log.debug("openHA: " + openHA + ", closeHA: " + closeHA);
    //In case we were long we check if we have at least one bull candle (positive) in our heiken ashi candle interval to not close the operation
    if (operation_type == OP_BUY) {
      _log.debug("We are looking for a bull candle");
      bool is_bull_candle = openHA < closeHA;
      _log.debug("is_bull_candle: " + is_bull_candle);
      if (is_bull_candle) { return false; }
    //In case we were short we check if we have at least one bear candle (negative) in our heiken ashi candle interval to not close the operation
    } else if (operation_type == OP_SELL) {
      _log.debug("We are looking for a bear candle");
      bool is_bear_candle = openHA > closeHA;
      _log.debug("is_bear_candle: " + is_bear_candle);
      if (is_bear_candle) { return false;}
    }
  }
  //If we didn't find any candle in the same direction as our possition in the last N candles we need to close it
  _log.info("We found " + number_of_candles + " candles in the opposite direction, we will close the operation");
  return true;
}