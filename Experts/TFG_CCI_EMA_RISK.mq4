//+------------------------------------------------------------------+
//|         MACDHeinkenAshi.mq4                                                                         |
//|         Copyright 2024, Daniel Lois Nuevo.                                                          |
//|         Expert advisor based on CCI and EMA indicators                                              |
//|         Open long position if CCI is above the overbought level  and Price over the slow EMA        |
//|         Open short position if CCI is below the oversell level  and Price below the slow EMA        |
//|         Close long position if hits TP or SL. SL at X pips below the price, TP at N * X pips above  |
//|         Close short position if hits TP or SL. SL at X pips above the price, TP at N * X pips below |
//|         The EA will open a maximum of 4 positions at the same time                                  |
//+------------------------------------------------------------------+
#define VERSION   "1.0"
#define DATE     20240102
#define NAME    "MACDHeinkenAshi"

#property copyright "Copyright 2024, Daniel Lois Nuevo"
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
//pips distance to the stop loss. This paramerter is diferent for each market
input uint pipsDistance = 10000;
//Relationship between SL and TP (2.0 = TP - Price distance at 2 x pips distance of the SL - Price)
input double operationRisk = 2.00;
//Percentage of the account balance to be used in each operation (0.01 = 1%)
input double accPercentage = 0.1;
//Max number of operations to be opened at the same time
input int max_operations = 4;
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

    int total_operations = getTotalOpenPosition(magic_number);

    double ema = iMA(NULL, 0, ema_period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double cci = iCCI(NULL, 0, cci_period, PRICE_CLOSE, 1);
    double cci_prev_candle = iCCI(NULL, 0, cci_period, PRICE_CLOSE, 2);


    if (ema != 0 && total_operations < max_operations) {
        // We check if the market is bullish or bearish, we will only open positions in the direction of the market
          
          //It's bull market if the close price is above the EMA and the CCI cross the overbought level
          bool go_long = Close[1] >= ema && cci > cci_overbought_lvl && cci_prev_candle < cci_overbought_lvl;

          //It's bear market if the close price is below the EMA and the CCI cross the oversell level
          bool go_short = Close[1] <= ema && cci < cci_oversell_lvl && cci_prev_candle > cci_oversell_lvl;

          double actual_balance = initalBalance + eaProfit(magic_number, &_log);
      
          if (go_long) {
            //We will go long
            double valid_lotage = getLotSize(accPercentage, actual_balance, Ask, &_log);
            _log.debug("We open a long position");
             //We get the SL and TP for the short position
            double sl = Ask - pipsDistance * Point;
            double tp = Ask + operationRisk * pipsDistance * Point;

            OrderSend(Symbol(), OP_BUY, valid_lotage, Ask, slippage, sl, tp, "", magic_number);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
          }
    
          if (go_short) {
            //We will go short
            double valid_lotage = getLotSize(accPercentage, actual_balance, Bid, &_log);
            //We get the SL and TP for the short position
            double sl = Bid + pipsDistance * Point;
            double tp = Bid - operationRisk * pipsDistance * Point;

            _log.debug("We open a short position");
            OrderSend(Symbol(), OP_SELL, valid_lotage, Bid, slippage, sl, tp, "", magic_number);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {_log.error("Operation not open correctly: " + ErrorDescription(check));}
    
          }
        
      }
  }
  
//+------------------------------------------------------------------+
