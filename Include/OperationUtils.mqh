int getOpenPosition(int magic_number) {
    int total=OrdersTotal(); 
    int result = -1;

    //Check for an open position with the specified magic number
    for(int i=0;i<total && resultado==-1;i++) {
        bool success = OrderSelect(i,SELECT_BY_POS); 
        if(success && OrderMagicNumber() == magicNumber) {
            result=OrderTicket(); 
        } 
    }

    return(result);
}