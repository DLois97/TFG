
bool checkInitialParameters(uint slow_ema_period, uint fast_ema_period, uint signal_line_period, uint log_level){

    if (log_level>3) {
        Print("ERROR: (PARAMETERS) The log level cannot be bigger than 3");
        return true;
    }

    if (fast_ema_period > slow_ema_period) {
        if (log_level>0) {Print("ERROR: (PARAMETERS) The fast EMA period cannot be bigger than the slow EMA period");}
        return true;
    } 

    if (signal_line_period < 0) {
        if (log_level>0) {Print("ERROR: (PARAMETERS) The signal line period cannot be negative");}
        return true;
    }

    return false; 
}