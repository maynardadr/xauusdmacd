//+------------------------------------------------------------------+
//|                   MACD Cross Arrows Indicator (10-minute)        |
//|                   Author: Nard & ChatGPT (GPT-5)                 |
//+------------------------------------------------------------------+
#property copyright "maynardpaye.com"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Up Arrow (LONG)
#property indicator_label1  "LONG"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Down Arrow (SHORT)
#property indicator_label2  "SHORT"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Purple Confirmation Arrow
#property indicator_label3  "CONFIRM"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrPurple
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Buffers
double upArrowBuffer[];
double downArrowBuffer[];
double confirmArrowBuffer[];

//--- MACD settings
input int FastEMA   = 12;
input int SlowEMA   = 26;
input int SignalSMA = 9;

//--- Filters
input int LookbackLong  = 6;   // past MACD bars must be below zero before LONG
input int LookbackShort = 6;   // past MACD bars must be above zero before SHORT
input int ArrowOffset   = 100; // distance in points away from candle

//--- Time filter (UTC+8 active hours)
input int ActiveStartHour = 7;   // 7 AM UTC+8
input int ActiveEndHour   = 23;  // 11 PM UTC+8

//--- Handle
int macdHandle;

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"MACD Cross Arrows (10min)");
   SetIndexBuffer(0, upArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, downArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, confirmArrowBuffer, INDICATOR_DATA);

   // Wingdings arrow symbols
   PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Up arrow ↑
   PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Down arrow ↓
   PlotIndexSetInteger(2, PLOT_ARROW, 159);  // Purple confirmation ↑

   macdHandle = iMACD(_Symbol, PERIOD_M10, FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE);
   if(macdHandle == INVALID_HANDLE)
   {
      Print("Error creating MACD handle: ", GetLastError());
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
bool IsActiveTime()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(serverTime, t);

   // Convert to UTC+8
   int hourUTC8 = t.hour + 8;
   if(hourUTC8 >= 24) hourUTC8 -= 24;

   return (hourUTC8 >= ActiveStartHour && hourUTC8 < ActiveEndHour);
}

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
   ArraySetAsSeries(confirmArrowBuffer, true);

   // Check time window
   if(!IsActiveTime())
   {
      Comment("Trading window closed. Active between ",
              IntegerToString(ActiveStartHour), ":00 and ",
              IntegerToString(ActiveEndHour), ":00 UTC+8");
      return(rates_total);
   }

   int start = prev_calculated > 1 ? prev_calculated - 1 : 1;

   for(int i = start; i < rates_total - 1; i++)
   {
      upArrowBuffer[i] = EMPTY_VALUE;
      downArrowBuffer[i] = EMPTY_VALUE;
      confirmArrowBuffer[i] = EMPTY_VALUE;

      double prevDiff = macdMain[i+1] - macdSignal[i+1];
      double currDiff = macdMain[i] - macdSignal[i];

      //--- Bullish cross (MACD crosses above signal)
      if(prevDiff < 0 && currDiff > 0)
      {
         bool allBelowZero = true;
         for(int j = 1; j <= LookbackLong; j++)
         {
            if(macdSignal[i+j] >= 0) { allBelowZero = false; break; }
         }

         if(allBelowZero)
         {
            double lowVal = iLow(_Symbol, PERIOD_M10, i);
            upArrowBuffer[i] = lowVal - (_Point * ArrowOffset);
            
            int lookback = 10;
            if (i - lookback < 0) continue;  // prevent negative indexing

            // ✅ fixed search window (looks backward instead of forward)
            int lowestIndex = iLowest(_Symbol, PERIOD_M10, MODE_LOW, lookback, i - lookback);
            double lowestPrice = iLow(_Symbol, PERIOD_M10, lowestIndex);
            double highestPrice = iHigh(_Symbol, PERIOD_M10, lowestIndex);

            datetime boxTime = iTime(_Symbol, PERIOD_M10, lowestIndex);
            string boxName = "Box_Long_" + IntegerToString(boxTime);

            int halfWidth = 3;
            int leftIndex = lowestIndex + halfWidth;
            int rightIndex = MathMax(lowestIndex - halfWidth, 0);

            datetime timeLeft  = iTime(_Symbol, PERIOD_M10, leftIndex);
            datetime timeRight = iTime(_Symbol, PERIOD_M10, rightIndex);

            if(ObjectFind(0, boxName) != -1)
               ObjectDelete(0, boxName);

            ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, timeLeft, highestPrice, timeRight, lowestPrice);
            ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrAqua);
            ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, boxName, OBJPROP_BACK, true);

            // --- ✅ Refactored & fixed Purple confirmation arrow ---
            double currentPrice = iClose(_Symbol, PERIOD_M10, i);
            if(currentPrice > lowestPrice && currentPrice < highestPrice)
            {
               double candleRange = iHigh(_Symbol, PERIOD_M10, i) - iLow(_Symbol, PERIOD_M10, i);
               double offsetY = MathMax(_Point * (ArrowOffset * 4.0), candleRange * 0.2);
               confirmArrowBuffer[i] = iLow(_Symbol, PERIOD_M10, i) - offsetY;

               PlotIndexSetInteger(2, PLOT_ARROW, 225);    // ▲
               PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 3); // slightly bigger
            }
         }
      }

      //--- Bearish cross (MACD crosses below signal)
      if(prevDiff > 0 && currDiff < 0)
      {
         bool allAboveZero = true;
         for(int j = 1; j <= LookbackShort; j++)
         {
            if(macdSignal[i+j] <= 0) { allAboveZero = false; break; }
         }

         if(allAboveZero)
         {
            double highVal = iHigh(_Symbol, PERIOD_M10, i);
            downArrowBuffer[i] = highVal + (_Point * ArrowOffset);

            int lookback = 10;
            if (i - lookback < 0) continue;
            int highestIndex = iHighest(_Symbol, PERIOD_M10, MODE_HIGH, lookback, i - lookback);
            double highestPrice = iHigh(_Symbol, PERIOD_M10, highestIndex);
            double lowestPrice = iLow(_Symbol, PERIOD_M10, highestIndex);

            datetime boxTime = iTime(_Symbol, PERIOD_M10, highestIndex);
            string boxName = "Box_Short_" + IntegerToString(boxTime);

            int halfWidth = 3;
            int leftIndex = highestIndex + halfWidth;
            int rightIndex = MathMax(highestIndex - halfWidth, 0);

            datetime timeLeft  = iTime(_Symbol, PERIOD_M10, leftIndex);
            datetime timeRight = iTime(_Symbol, PERIOD_M10, rightIndex);

            if(ObjectFind(0, boxName) != -1)
               ObjectDelete(0, boxName);

            ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, timeLeft, highestPrice, timeRight, lowestPrice);
            ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
         }
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
