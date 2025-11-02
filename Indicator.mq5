//+------------------------------------------------------------------+
//|                      MACD Cross Arrows Indicator (10-minute)     |
//|                      Author: Nard & ChatGPT (GPT-5)              |
//+------------------------------------------------------------------+
#property copyright "maynardpaye.com"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Up Arrow
#property indicator_label1  "LONG"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Down Arrow
#property indicator_label2  "SHORT"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Buffers
double upArrowBuffer[];
double downArrowBuffer[];

//--- MACD settings
input int FastEMA   = 12;
input int SlowEMA   = 26;
input int SignalSMA = 9;

//--- Handle
int macdHandle;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"MACD Cross Arrows (10min)");
   SetIndexBuffer(0, upArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, downArrowBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow

   macdHandle = iMACD(_Symbol, PERIOD_M10, FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE);
   if(macdHandle == INVALID_HANDLE)
   {
      Print("Error creating MACD handle: ", GetLastError());
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   if(rates_total < 50) return(0);

   static double macdMain[], macdSignal[];
   if(CopyBuffer(macdHandle, 0, 0, rates_total, macdMain) <= 0) return(0);
   if(CopyBuffer(macdHandle, 1, 0, rates_total, macdSignal) <= 0) return(0);

   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(upArrowBuffer, true);
   ArraySetAsSeries(downArrowBuffer, true);

   int start = prev_calculated > 1 ? prev_calculated - 1 : 1;

   for(int i = start; i < rates_total - 1; i++)
   {
      upArrowBuffer[i] = EMPTY_VALUE;
      downArrowBuffer[i] = EMPTY_VALUE;

      double prevDiff = macdMain[i+1] - macdSignal[i+1];
      double currDiff = macdMain[i] - macdSignal[i];

      //--- Bullish cross (MACD crosses above signal)
      if(prevDiff < 0 && currDiff > 0)
      {
         double lowVal = iLow(_Symbol, PERIOD_M10, i);
         upArrowBuffer[i] = lowVal - (_Point * 100);
         Comment("LONG signal @ ", TimeToString(iTime(_Symbol, PERIOD_M10, i)), 
                 " | Price=", DoubleToString(iClose(_Symbol, PERIOD_M10, i), 5));
      }

      //--- Bearish cross (MACD crosses below signal)
      if(prevDiff > 0 && currDiff < 0)
      {
         double highVal = iHigh(_Symbol, PERIOD_M10, i);
         downArrowBuffer[i] = highVal + (_Point * 100);
         Comment("SHORT signal @ ", TimeToString(iTime(_Symbol, PERIOD_M10, i)), 
                 " | Price=", DoubleToString(iClose(_Symbol, PERIOD_M10, i), 5));
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
