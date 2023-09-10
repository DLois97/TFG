#include <Logger.mqh>

int getOpenPosition(int magic_n, Logger *logger, bool isLong) {
    int total=OrdersTotal(); 
    int result = -1;

    //Check for an open position with the specified magic number
    for(int i=0;i<total && result==-1;i++) {
        bool success = OrderSelect(i,SELECT_BY_POS); 
        if(success && OrderMagicNumber() == magic_n && ((isLong && OrderType() == OP_BUY) || (!isLong && OrderType() == OP_SELL))) {
            result=OrderTicket(); 
            logger.debug("Found open position: " + result);
        } 
    }

    return(result);
}

bool closePosition(int idOp, Logger *logger) {
    logger.debug("Trying to close order: " +idOp);
    bool success = OrderSelect(idOp, SELECT_BY_TICKET);
    double price = (OrderType() == OP_BUY) ? Bid : Ask;
    if (success) {
       logger.info("Closing order: " + OrderTicket() + " at price: " + price);
       return OrderClose(idOp, OrderLots() , price, 0, Red); 
    }
    return false;
}

bool handleOpenPosition(long id_operation, int opposite_candles, Logger *logger){
    bool order_selected = OrderSelect(id_operation, SELECT_BY_TICKET);
    bool order_closed = false;
    //If we have an open position, we check if we have to close it
    //We will close the long or short position in case we found X Heiken Ashi candles in the opposite direction
    if (order_selected) {
        if (OrderType() == OP_BUY) {
            bool close_long = checkCloseOperation(opposite_candles, OP_BUY);
            if (close_long) {
                _log.debug("We want to close a long position");
                order_closed = closePosition(id_operation, logger);
            }
        } else if (OrderType() == OP_SELL){
            bool close_short = checkCloseOperation(opposite_candles, OP_SELL);
            if (close_short) {
                _log.debug("We want to close a short position");
                order_closed = closePosition(id_operation, logger);
            }
        }
    }
    return order_closed;
}

bool checkCloseOperation(int number_of_candles, int operation_type) {
  for (int i = 0; i < number_of_candles; i++) {
    //We get the open and close values for the Heiken Ashi candles we don't care about the high and low values because we are not going to use them
    _log.debug("We are checking the candle number " + i);
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
  _log.info("We found " + number_of_candles + " candles in the opposite direction, we will close the operation");
  return true;
}

int openPosition(int operation_type, double lot, int magic_n, Logger *logger) {
 logger.info("Opening order: " + operation_type + " with lotage: " + lot);
 double price = (OrderType() == OP_BUY) ? Ask : Bid;
 int ticket = OrderSend(NULL, operation_type, lot, price, 0, 0, 0, "", magic_n);
 if (ticket < 0) {
     //If the error is ERR_NO_CONNECTION, we will wait for 5 ticks to see if the connection is restored
     if (GetLastError() == ERR_NO_CONNECTION && !IsTesting() && !IsOptimization()) {
          while (!RefreshRates()) {
             logger.error("No connection, waiting server response...");
             Sleep(2000); // Esperar antes de volver a intentar
         }
     }
     logger.error("Error opening order: " + GetLastError());
 }

 return(ticket);
}

double getLotSize(double risk, double balance, double price, Logger *logger) {
    //We get the lot size based on the risk percentage of the account balance
    double valueAccountLot = AccountBalance() * risk;
    logger.debug("Value account lot: " + valueAccountLot);
    double lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
    logger.debug("lotSize: " + lotSize);
    double lot = valueAccountLot / (lotSize * price);
    logger.debug("real target lot: " + lot);
    //We round the lot size to the nearest allow value

    //We get the minimum and maximum lot size allowed
    double minimumLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maximumLot = MarketInfo(Symbol(), MODE_MAXLOT);
    logger.debug("minimumLot: " + minimumLot);
    logger.debug("maximumLot: " + maximumLot);
    //We get the lot step
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    logger.debug("lotStep: " + lotStep);
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
    logger.info("total EA profit: " + profit);
    return(profit);
}
