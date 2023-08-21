#include <Logger.mqh>

double HAOpenBuffer[50];
double HACloseBuffer[50];
double HAHighBuffer[50];
double HALowBuffer[50];
int prev_calculated = 0;

//TODO: Hay que hacer que los buffers sean dinámicos y a la hora de vulver a calcular las velas ya generadas
//No se vuelva a hacer calculos ya realizados
//Este fragmento de código es el indicador "Heiken Ashi.mq4" extraido fuera del onCalculate()
void generateHeikenAshiValues(){
    int    i,pos;
    double haOpen,haHigh,haLow,haClose;
    _log.info("Bars; " + Bars);
    if (Bars <= 10) {
        return;
    }
    if (ArraySize(HAOpenBuffer) <= Bars) {
        _log.info("Entramos en el Resize");
        ArrayResize(HAOpenBuffer, Bars*2);
        ArrayResize(HACloseBuffer, Bars*2);
        ArrayResize(HAHighBuffer, Bars*2);
        ArrayResize(HALowBuffer, Bars*2);
    }
    ArraySetAsSeries(HALowBuffer,true);
    ArraySetAsSeries(HAHighBuffer,true);
    ArraySetAsSeries(HAOpenBuffer,true);
    ArraySetAsSeries(HACloseBuffer,true);

    HAOpenBuffer[i] = (Open[i] + Close[i]) / 2;
    HACloseBuffer[i] = (Open[i] + High[i] + Low[i] + Close[i]) / 4;
    HAHighBuffer[i] = MathMax(High[i], MathMax(HAOpenBuffer[i], HACloseBuffer[i]));
    HALowBuffer[i] = MathMin(Low[i], MathMin(HAOpenBuffer[i], HACloseBuffer[i]));
    
    _log.info("Entramos a los calculos previos");
    if(prev_calculated>1) {
        pos=prev_calculated-1;
    } else {
        //--- set first candle
        _log.info("Calculamos la primera vela");
        if(Open[0]<Close[0]) {
            HALowBuffer[0]=Low[0];
            HAHighBuffer[0]=High[0];
        } else {
            HALowBuffer[0]=High[0];
            HAHighBuffer[0]=Low[0];
        }
        HAOpenBuffer[0]=Open[0];
        HACloseBuffer[0]=Close[0];
        //---
        pos=1;
    }
    //--- main loop of calculations
   for(i=pos; i<Bars; i++) {
        _log.info("Calculamos la  vela" + i);
        haOpen=(HAOpenBuffer[i-1]+HACloseBuffer[i-1])/2;
        haClose=(Open[i]+High[i]+Low[i]+Close[i])/4;
        haHigh=MathMax(High[i],MathMax(haOpen,haClose));
        haLow=MathMin(Low[i],MathMin(haOpen,haClose));
        if(haOpen<haClose) {
            HALowBuffer[i]=haLow;
            HAHighBuffer[i]=haHigh;
        } else {
            HALowBuffer[i]=haHigh;
            HAHighBuffer[i]=haLow;
        }
        HAOpenBuffer[i]=haOpen;
        HACloseBuffer[i]=haClose;
        _log.info("fin calculo de la  vela" + i);
    }

    prev_calculated=i;

//--- done
    

}



