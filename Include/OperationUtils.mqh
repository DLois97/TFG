#include <Logger.mqh>

int getOpenPosition(int magic_n, Logger *logger) {
    int total=OrdersTotal(); 
    int result = -1;

    //Check for an open position with the specified magic number
    for(int i=0;i<total && result==-1;i++) {
        bool success = OrderSelect(i,SELECT_BY_POS); 
        if(success && OrderMagicNumber() == magic_n) {
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
