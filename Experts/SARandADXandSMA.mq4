//+------------------------------------------------------------------+
//|                                              MACDHeinkenAshi.mq4 |
//|                                  Copyright 2023, Daniel Lois Nuevo. |
//|                                            |
//+------------------------------------------------------------------+
#define VERSION   "1.0"
#define DATE     20230810
#define NAME    "MACDHeinkenAshi"

#property copyright "Copyright 2023, Daniel Lois Nuevo"
#property version   VERSION
#property link      "https://github.com/DLois97"
#property strict

#include <Logger.mqh>
#include <OperationUtils.mqh>
#include <stderror.mqh>
#include <stdlib.mqh>

input double sarStep = 0.02;
input double sarMaximum = 0.2;
input uint adxPeriod = 14;
input uint maPeriod = 200;
input uint adxLevel = 25;
//Percentage of the account balance to be used in each operation (0.01 = 1%)
input double riskParameter = 0.01;

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
int id_operation;
double initalBalance;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  _log = Logger(log_level);
  log_pointer = &_log;
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
    //Our EA will only work once by candle, so we check if the last candle has finished
    //We check if the last candle has finished
    if (Time[0]<=last_candle_process_time) {
      return;
    } else {
      last_candle_process_time = Time[0];
    }

    //We get the id of the open positions by our EA
    id_operation = getOpenPosition(magic_number, log_pointer);

    double sma = iMA(NULL, 0, maPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
    double sar = iSAR(NULL, 0, sarStep, sarMaximum, 1);
    double adx = iADX(NULL, 0, adxPeriod, PRICE_CLOSE, MODE_MAIN, 1);
    
    //First we check if we have an open position, in case we have one, we check if It's Long or short position to update correctly each OrderId
    if (sma != 0) {
       if (id_operation != -1) {
           bool order_closed = checkClosePosition(id_operation, sar, sma);
           if (order_closed) {
               id_operation = -1;
           }
       } else {

        if (adx > adxLevel) {
        // We check if the market is bullish or bearish, we will only open positions in the direction of the market
          bool bullMarkey = Close[1] >= sma;
          bool go_long = bullMarkey && (id_operation == -1) && (Close[1] > sar);
          bool go_short = !(bullMarkey) && (id_operation == -1) && (Close[1] < sar);
          double actual_balance = initalBalance + eaProfit(magic_number, log_pointer);
        
    
          if (go_long) {
            //We will go long in case we have the MACD above the signal line and tha MACD is possitive (above 0)
            double valid_lotage = getLotSize(riskParameter, actual_balance, Ask, log_pointer);
            _log.debug("We open a long position");
            id_operation = OrderSend(Symbol(), OP_BUY, valid_lotage, Ask, slippage, 0, 0, "", magic_number);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
          }
    
          if (go_short) {
            //We will go short in case we have the MACD below the signal line and tha MACD is negative (below 0)
            double valid_lotage = getLotSize(riskParameter, actual_balance, Bid, log_pointer);
            _log.debug("We open a short position");
            id_operation = OrderSend(Symbol(), OP_SELL, valid_lotage, Bid, slippage, 0, 0, "", magic_number);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
    
          }
        }
      }
    }
  }

    


//---
   
  
//+------------------------------------------------------------------+

bool checkClosePosition(long id_operation, double _sar, double _sma){
    bool order_selected = OrderSelect(id_operation, SELECT_BY_TICKET);
    bool order_closed = false;
    //If we have an open position, we check if we have to close it
    //We will close the long or short position in case we found X Heiken Ashi candles in the opposite direction
    if (order_selected) {
      bool close_op = false;
       _log.debug("close: " + Close[1] + ", sma: " + _sma + " _sar:" + _sar);
      if (OrderType() == OP_BUY) {
        _log.debug("We close a long position");
        close_op = _sma > Close[1] || _sar > Close[1];
      } else {
         _log.debug("We close a short position");
        close_op = _sma < Close[1] || _sar < Close[1];
      }
      
      if (close_op) {
          _log.debug("We want to close the position");
          order_closed = closePosition(id_operation, &_log);
          int check=GetLastError();
          if(check!=ERR_NO_ERROR) {_log.error("Order not close correctly: " + ErrorDescription(check));}
      }
    }
    return order_closed;
}

