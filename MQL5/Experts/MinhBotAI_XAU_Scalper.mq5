//+------------------------------------------------------------------+
//|                                                   MinhBotAI_XAU_Scalper.mq5 |
//|                                   Created by ChatGPT for MT5 EA  |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input double RiskPercent = 1.0;        // Risk per trade (% of balance)
input int MaxSpreadPoints = 25;        // Max spread in points
input double ATRMultSL = 1.5;          // Stop loss ATR multiplier
input double ATRMultTP = 2.0;          // Take profit ATR multiplier
input int StartHourVN = 13;            // Trading start hour (Vietnam time)
input int EndHourVN = 23;              // Trading end hour (Vietnam time)
input long MagicNumber = 20250201;     // Magic number

CTrade trade;
int ema15Handle = INVALID_HANDLE;
int ema21Handle = INVALID_HANDLE;
int ema35Handle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

datetime lastM5BarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ema15Handle = iMA(_Symbol, PERIOD_M15, 15, 0, MODE_EMA, PRICE_CLOSE);
   ema21Handle = iMA(_Symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   ema35Handle = iMA(_Symbol, PERIOD_M15, 35, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M5, 14);

   if(ema15Handle == INVALID_HANDLE || ema21Handle == INVALID_HANDLE || ema35Handle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(_Symbol);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema15Handle != INVALID_HANDLE)
      IndicatorRelease(ema15Handle);
   if(ema21Handle != INVALID_HANDLE)
      IndicatorRelease(ema21Handle);
   if(ema35Handle != INVALID_HANDLE)
      IndicatorRelease(ema35Handle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewM5Bar())
      return;

   if(!IsTradingTimeVN())
      return;

   if(!CheckSpread())
      return;

   if(PositionSelect(_Symbol))
      return;

   double ema15 = 0.0, ema21 = 0.0, ema35 = 0.0;
   if(!GetEMAValues(ema15, ema21, ema35))
      return;

   bool trendBuy = (ema35 > ema21 && ema35 > ema15);
   bool trendSell = (ema35 < ema21 && ema35 < ema15);

   double atrValue = GetATRValue();
   if(atrValue <= 0.0)
      return;

   double vwapValue = GetSessionVWAP();
   if(vwapValue <= 0.0)
      return;

   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double open1 = iOpen(_Symbol, PERIOD_M5, 1);

   if(trendBuy && close1 > vwapValue && close1 > open1)
   {
      OpenPosition(ORDER_TYPE_BUY, atrValue);
   }
   else if(trendSell && close1 < vwapValue && close1 < open1)
   {
      OpenPosition(ORDER_TYPE_SELL, atrValue);
   }
}

//+------------------------------------------------------------------+
//| Check if a new M5 bar has formed                                 |
//+------------------------------------------------------------------+
bool IsNewM5Bar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBarTime == 0)
      return false;

   if(currentBarTime != lastM5BarTime)
   {
      lastM5BarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check trading time in VN (UTC+7)                                 |
//+------------------------------------------------------------------+
bool IsTradingTimeVN()
{
   datetime serverTime = TimeCurrent();
   datetime gmtTime = TimeGMT();
   int serverOffset = (int)(serverTime - gmtTime);
   int vnOffset = 7 * 3600;
   datetime vnTime = serverTime + (vnOffset - serverOffset);

   MqlDateTime dt;
   TimeToStruct(vnTime, dt);

   if(StartHourVN <= EndHourVN)
      return (dt.hour >= StartHourVN && dt.hour < EndHourVN);

   // Handle overnight sessions if needed
   return (dt.hour >= StartHourVN || dt.hour < EndHourVN);
}

//+------------------------------------------------------------------+
//| Check spread                                                     |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double spreadPoints = (ask - bid) / _Point;
   return (spreadPoints <= MaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Get EMA values from M15                                          |
//+------------------------------------------------------------------+
bool GetEMAValues(double &ema15, double &ema21, double &ema35)
{
   double buffer15[2];
   double buffer21[2];
   double buffer35[2];

   if(CopyBuffer(ema15Handle, 0, 1, 1, buffer15) != 1)
      return false;
   if(CopyBuffer(ema21Handle, 0, 1, 1, buffer21) != 1)
      return false;
   if(CopyBuffer(ema35Handle, 0, 1, 1, buffer35) != 1)
      return false;

   ema15 = buffer15[0];
   ema21 = buffer21[0];
   ema35 = buffer35[0];

   return true;
}

//+------------------------------------------------------------------+
//| Get ATR value from M5                                            |
//+------------------------------------------------------------------+
double GetATRValue()
{
   double buffer[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, buffer) != 1)
      return 0.0;

   return buffer[0];
}

//+------------------------------------------------------------------+
//| Calculate session VWAP (daily reset)                             |
//+------------------------------------------------------------------+
double GetSessionVWAP()
{
   datetime dayStart = GetDayStart(TimeCurrent());
   MqlRates rates[];

   int copied = CopyRates(_Symbol, PERIOD_M5, dayStart, TimeCurrent(), rates);
   if(copied <= 1)
      return 0.0;

   ArraySetAsSeries(rates, true);
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);

   double totalPV = 0.0;
   double totalVol = 0.0;

   for(int i = 0; i < copied; i++)
   {
      if(rates[i].time >= currentBarTime)
         continue;

      double typicalPrice = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double volume = (double)rates[i].tick_volume;
      totalPV += typicalPrice * volume;
      totalVol += volume;
   }

   if(totalVol <= 0.0)
      return 0.0;

   return totalPV / totalVol;
}

//+------------------------------------------------------------------+
//| Day start                                                        |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime timeValue)
{
   MqlDateTime dt;
   TimeToStruct(timeValue, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   if(slDistancePoints <= 0.0)
      return 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;

   double valuePerPoint = tickValue / tickSize * _Point;
   double lot = riskAmount / (slDistancePoints * valuePerPoint);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = NormalizeLot(lot, lotStep, minLot);

   return lot;
}

//+------------------------------------------------------------------+
//| Normalize lot                                                    |
//+------------------------------------------------------------------+
double NormalizeLot(double lot, double step, double minLot)
{
   if(step <= 0.0)
      return lot;

   double normalized = MathFloor((lot - minLot) / step) * step + minLot;
   if(normalized < minLot)
      normalized = minLot;

   return normalized;
}

//+------------------------------------------------------------------+
//| Open position                                                    |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType, double atrValue)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   double slDistance = atrValue * ATRMultSL;
   double tpDistance = atrValue * ATRMultTP;

   double sl = 0.0;
   double tp = 0.0;
   double price = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      price = ask;
      sl = price - slDistance;
      tp = price + tpDistance;
   }
   else
   {
      price = bid;
      sl = price + slDistance;
      tp = price - tpDistance;
   }

   double slPoints = slDistance / _Point;
   double lot = CalculateLotSize(slPoints);
   if(lot <= 0.0)
      return;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);

   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lot, _Symbol, price, sl, tp, "MinhBotAI XAU Scalper");
   else
      result = trade.Sell(lot, _Symbol, price, sl, tp, "MinhBotAI XAU Scalper");

   if(!result)
      Print("Order failed. Retcode: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
}
