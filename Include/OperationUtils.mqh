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
     if (GetLastError() == ERR_NO_CONNECTION) {
          while (!RefreshRates()) {
             logger.error("No connection, waiting server response...");
             Sleep(2000); // Esperar antes de volver a intentar
         }
     }
     logger.error("Error opening order: " + GetLastError());
 }

 return(ticket);
}
