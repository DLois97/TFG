#include <Logger.mqh>

double getOpenHeikenAshi(int period, Logger *logger) {
    logger.debug("Calculating open heiken ashi candle");
    double previous_candle_open = Open[period - 1];
    double previous_candle_close = Close[period - 1];
    double result = ((previous_candle_open + previous_candle_close) / 2);
    logger.info("calculating open heiken ashi for period: " + period + " previous_candle_open: " + previous_candle_open + " previous_candle_close: " + previous_candle_close + " result: " + result);
    return (result); 
}

double getCloseHeikenAshi(int period, Logger *logger) {
    logger.debug("Calculating close heiken ashi candle");
    double open = Open[period];
    double close = Close[period];
    double high = High[period];
    double low = Low[period];
    double result = ((open + high + low + close) / 4);
    logger.info("calculating close heiken ashi for period: " + period + " open: " + open + " close: " + close + " high: " + high + " low: " + low + " result: " + result);
    return (result); 
}

double getHighHeikenAshi(int period, Logger *logger) {
    logger.debug("Calculating high heiken ashi candle");
    double openHA = getOpenHeikenAshi(period, logger);
    double closeHA =getCloseHeikenAshi(period, logger);
    double high = High[period];
    double result = MathMax(high, MathMax(openHA, closeHA));
    logger.info("calculating high heiken ashi for period: " + period + " openHA: " + openHA + " closeHA: " + closeHA + " high:" + high + " result: " + result);
    return (result); 
}

double getLowHeikenAshi(int period, Logger *logger) {
    logger.debug("Calculating low heiken ashi candle");
    double openHA = getOpenHeikenAshi(period, logger);
    double closeHA =getCloseHeikenAshi(period, logger);
    double low = Low[period];
    double result = MathMin(low, MathMin(openHA, closeHA));
    logger.info("calculating low heiken ashi for period: " + period + " openHA: " + openHA + " closeHA: " + closeHA + " low:" + low + " result: " + result);
    return (result); 
}

