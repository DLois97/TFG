#property copyright "Copyright 2023, Daniel Lois Nuevo"
#property link      "https://github.com/DLois97"
#property version   "1.0"

#include <Logger.mqh>

int getOpenPosition(int magic_n, Logger *logger, bool isLong) {
    int total=OrdersTotal(); 
    int result = -1;

    //Check for an open position with the specified magic number
    for(int i=0;i<total && result==-1;i++) {
        bool success = OrderSelect(i,SELECT_BY_POS); 
        if(success && OrderMagicNumber() == magic_n && ((isLong && OrderType() == OP_BUY) || (!isLong && OrderType() == OP_SELL))) {
            result=OrderTicket(); 
            //logger.debug("Found open position: " + result);
        } 
    }

    return(result);
    }

    
int getOpenPosition(int magic_n, Logger *logger) {
    int total=OrdersTotal(); 
    int result = -1;

    //Check for an open position with the specified magic number
    for(int i=0;i<total && result==-1;i++) {
        bool success = OrderSelect(i,SELECT_BY_POS); 
        if(success && OrderMagicNumber() == magic_n) {
            result=OrderTicket(); 
            //logger.debug("Found open position: " + result);
        } 
    }

    return(result);
    }


bool closePosition(int idOp, Logger *logger) {
    //logger.debug("Trying to close order: " +idOp);
    bool success = OrderSelect(idOp, SELECT_BY_TICKET);
    double price = (OrderType() == OP_BUY) ? Bid : Ask;
    if (success) {
       //logger.info("Closing order: " + OrderTicket() + " at price: " + price);
       return OrderClose(idOp, OrderLots() , price, 0, Red); 
    }
    return false;
}

//This method first check if we have to  close the operation and then it will close it
bool handleOpenPosition(long id_operation, int opposite_candles, Logger *logger){
    bool order_selected = OrderSelect(id_operation, SELECT_BY_TICKET);
    bool order_closed = false;
    //If we have an open position, we check if we have to close it
    //We will close the long or short position in case we found X Heiken Ashi candles in the opposite direction
    if (order_selected) {
        bool close_op = checkCloseOperation(opposite_candles, OrderType());
        if (close_op) {
            _log.debug("We want to close the position");
            order_closed = closePosition(id_operation, logger);
            int check=GetLastError();
            if(check!=ERR_NO_ERROR) {logger.error("Order not close correctly: " + ErrorDescription(check));}
        }
    }
    return order_closed;
}

/*
In this method we get the number of candles that we want to check in order to close our open operation. 
If the operation_type variable correspond with OP_BUY we will check if we have at least one bull candle in the last N candles.
If the operation_type variable correspond with OP_SELL we will check if we have at least one bear candle in the last N candles.
*/  
bool checkCloseOperation(int number_of_candles, int operation_type) {
  for (int i = 1; i <= number_of_candles; i++) {
    //We get the open and close values for the Heiken Ashi candles to know if there is a bull or bear candle
    //We use the iCustom function to get the values of the Heiken Ashi candles, for the open values we have to use 2 as mode variable
    //and for the close values we have to use 3.
    double openHA = iCustom(NULL, 0, "Heiken Ashi", 0, 2, i);
    double closeHA = iCustom(NULL, 0, "Heiken Ashi", 0, 3, i);

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
  _log.debug("We found " + number_of_candles + " candles in the opposite direction, we will close the operation");
  return true;
}


//This method will return the lot size based on the risk percentage of the account balance
double getLotSize(double risk, double balance, double price, Logger *logger) {
    double valueAccountLot = AccountBalance() * risk;
    //logger.debug("Value account lot: " + valueAccountLot);
    double lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
    //logger.debug("lotSize: " + lotSize);
    double lot = valueAccountLot / (lotSize * price);
    //logger.debug("real target lot: " + lot);
    //We round the lot size to the nearest allow value

    //We get the minimum and maximum lot size allowed
    double minimumLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maximumLot = MarketInfo(Symbol(), MODE_MAXLOT);
    //logger.debug("minimumLot: " + minimumLot);
    //logger.debug("maximumLot: " + maximumLot);
    //We get the lot step
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    //logger.debug("lotStep: " + lotStep);
    double roundedLot = lot;
    //If the lot size is less than the minimum allowed, we set the minimum allowed
    if (lot < minimumLot) {
        roundedLot = minimumLot;
    //If the lot size is greater than the maximum allowed, we set the maximum allowed
    } else if (lot > maximumLot) {
        roundedLot = maximumLot;
    //If the lot size is between the minimum and maximum allowed, we round the lot size to the nearest allowed value
    } else {
        double topRoundedLot = minimumLot;
        //Looking for the first value greater than the lot size allowed
        while (topRoundedLot < lot) {
            topRoundedLot += lotStep;
        }
        //Get the previous value to the lot size allowed
        double bottomRoundedLot = topRoundedLot - lotStep;
        //If the difference between out target lot size and the top rounded lot size is less than the difference between the target lot
        //size and the bottom rounded lot size, we set the top rounded lot size as our tartet lot size allowed
        if (topRoundedLot - lot > lot - bottomRoundedLot) {
            roundedLot = bottomRoundedLot;
        //If the difference between out target lot size and the bottom rounded lot size is less than the difference between the target lot
        //size and the top rounded lot size, we set the bottom rounded lot size as our tartet lot size allowed
        } else {
            roundedLot = topRoundedLot;
        }
    }
    logger.info("roundedLot: " + roundedLot);

    return (roundedLot);
}

double eaProfit(int magic_n, Logger *logger) {
    double profit = 0;
    int total=OrdersHistoryTotal(); 
    //Check for an open position with the specified magic number
    for(int i=0;i<total;i++) {
        bool success = OrderSelect(i,SELECT_BY_POS, MODE_HISTORY); 
        if(success && OrderMagicNumber() == magic_n) {
            profit += OrderProfit() + OrderCommission() + OrderSwap();
        } 
    }
    //logger.info("total EA profit: " + profit);
    return(profit);
}
