//+------------------------------------------------------------------+
//|                                              MACDHeinkenAshi.mq4 |
//|                                  Copyright 2023, Daniel Lois Nuevo. |
//|                                            |
//+------------------------------------------------------------------+
#define VERSION   "1.0"
#define DATE     20240102
#define NAME    "MACDHeinkenAshi"

#property copyright "Copyright 2023, Daniel Lois Nuevo"
#property version   VERSION
#property link      "https://github.com/DLois97"
#property strict

#include <Logger.mqh>
#include <OperationUtils.mqh>
#include <stderror.mqh>
#include <stdlib.mqh>

input uint ema_period = 100;
input uint cci_period = 14;
input uint cci_overbought_lvl = 100;
input int cci_oversell_lvl = -100;
input uint rsi_period = 14;
input uint rsi_overbought_lvl = 70;
input uint rsi_oversell_lvl = 30;
input double sar_step = 0.02;
input double sar_max_step = 0.2;
//Percentage of the account balance to be used in each operation (0.01 = 1%)
input double riskParameter = 0.1;
input uint log_level = 0;
input int magic_number = DATE;
input int slippage = 3;

//Global variables for the expert advisor
datetime last_candle_process_time;
Logger _log;
int id_current_op;
double initalBalance;
bool rsi_crossed = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  _log = Logger(log_level);
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
    id_current_op = getOpenPosition(magic_number, &_log);

    double ema = iMA(NULL, 0, ema_period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double sar = iSAR(NULL, 0, sar_step, sar_max_step, 1);
    //double sar = iCustom(NULL, 0, "Parabolic", sar_step, sar_max_step, 0, 1);
    double cci = iCCI(NULL, 0, cci_period, PRICE_CLOSE, 1);
    double rsi = iRSI(NULL, 0, rsi_period, PRICE_CLOSE, 1);

    //We check if the RSI is above the overbought level or below the oversell level
    if (!rsi_crossed){
      rsi_crossed = (rsi > rsi_overbought_lvl) || (rsi < rsi_oversell_lvl);
    }

    //First we check if we have an open position, in case we have one, we check if It's Long or short position to update correctly each OrderId
    if (ema != 0) {
       if (id_current_op != -1) {
           bool order_closed = checkClosePosition(id_current_op, sar, ema, rsi);
           if (order_closed) {
               id_current_op = -1;
           }
       } else {
        // We check if the market is bullish or bearish, we will only open positions in the direction of the market
          
          //It's bull market if the close price is above the EMA and the CCI is above the overbought level and the SAR is below the close price
          bool bullMarket = Close[1] >= ema && cci > cci_overbought_lvl && (Close[1] > sar);

          //It's bear market if the close price is below the EMA and the CCI is below the oversell level and the SAR is above the close price
          bool bearMarket = Close[1] <= ema && cci < cci_oversell_lvl && (Close[1] < sar);

          bool go_long = bullMarket && (id_current_op == -1) ;
          bool go_short = bearMarket && (id_current_op == -1) ;
          double actual_balance = initalBalance + eaProfit(magic_number, &_log);
      
          if (go_long) {
            //We will go long
            double valid_lotage = getLotSize(riskParameter, actual_balance, Ask, &_log);
            _log.debug("We open a long position");
            id_current_op = OrderSend(Symbol(), OP_BUY, valid_lotage, Ask, slippage, 0, 0, "", magic_number);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
          }
    
          if (go_short) {
            //We will go short
            double valid_lotage = getLotSize(riskParameter, actual_balance, Bid, &_log);
            _log.debug("We open a short position");
            id_current_op = OrderSend(Symbol(), OP_SELL, valid_lotage, Bid, slippage, 0, 0, "", magic_number);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
    
          }
        
      }
    }
  }
//+------------------------------------------------------------------+

bool checkClosePosition(long _id_current_op, double _sar, double _ema, double _rsi){
    bool order_selected = OrderSelect(_id_current_op, SELECT_BY_TICKET);
    bool order_closed = false;
    //If we have an open position, we check if we have to close it
    //We will close the long or short position in case we found X Heiken Ashi candles in the opposite direction
    if (order_selected) {
      bool close_op = false;
      bool closeRSI = false;
      bool closeSAR = false;
      bool closeEMA = false;
       _log.info("close: " + Close[1] + ", sma: " + _ema + " _sar:" + _sar + " _rsi:" + _rsi);
      if (OrderType() == OP_BUY) {
        _log.debug("We close a long position");
        close_op = _ema > Close[1] || _sar > Close[1] || (rsi_crossed && _rsi < rsi_overbought_lvl);
        closeRSI = rsi_crossed && _rsi < rsi_overbought_lvl;
        closeSAR = _sar > Close[1];
        closeEMA = _ema > Close[1];
      } else {
         _log.debug("We close a short position");
        close_op = _ema < Close[1] || _sar < Close[1] || (rsi_crossed && _rsi > rsi_oversell_lvl);
        closeRSI = rsi_crossed && _rsi > rsi_overbought_lvl;
        closeSAR = _sar < Close[1];
        closeEMA = _ema < Close[1];
      }
      
      if (close_op) {
          _log.debug("We want to close the position");
          _log.info("Close buy for RSI: " + closeRSI);
          _log.info("Close buy for SAR: " + closeSAR);
          _log.info("Close buy for EMA: " + closeEMA);
          order_closed = closePosition(_id_current_op, &_log);
          if (order_closed) { rsi_crossed = false; }
          int check=GetLastError();
          if(check!=ERR_NO_ERROR) {_log.error("Order not close correctly: " + ErrorDescription(check));}
      }
    }
    return order_closed;
}