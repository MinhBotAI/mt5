# MinhBotAI XAUUSD Scalper (MT5 Expert Advisor)

This repository contains an MT5 Expert Advisor designed for XAUUSD scalping using a multi-timeframe trend filter and a daily-reset VWAP entry trigger.

## Strategy Summary
- **Symbol**: Uses `_Symbol` (works with XAUUSD and broker suffixes like XAUUSDm).
- **Entry timeframe**: M5.
- **Trend filter timeframe**: M15 using EMA 15/21/35.
- **Trend filter**:
  - Buy-only when EMA35 > EMA21 and EMA35 > EMA15 (M15).
  - Sell-only when EMA35 < EMA21 and EMA35 < EMA15 (M15).
- **Entry rules (M5)**:
  - Buy when the last closed candle is bullish and closes above VWAP.
  - Sell when the last closed candle is bearish and closes below VWAP.
- **Risk & exits**:
  - Risk per trade: 1% of balance (adjustable).
  - Stop Loss: 1.5 × ATR(14) on M5.
  - Take Profit: 2.0 × ATR(14) on M5.
  - Max spread filter (default 25 points).
  - One open position per symbol.
  - Trading hours: 13:00–23:00 Vietnam time (UTC+7), auto-converted to server time.

## File Location
- EA source: `MQL5/Experts/MinhBotAI_XAU_Scalper.mq5`

## Inputs
- `RiskPercent`: Risk per trade as a percentage of balance.
- `MaxSpreadPoints`: Maximum allowable spread (points).
- `ATRMultSL`: Stop Loss ATR multiplier.
- `ATRMultTP`: Take Profit ATR multiplier.
- `StartHourVN`: Trading session start hour (Vietnam time).
- `EndHourVN`: Trading session end hour (Vietnam time).
- `MagicNumber`: Magic number for the EA.

## How to Run
1. Copy the `MQL5` folder into your MT5 data directory, or place the EA file directly in `MQL5/Experts/`.
2. Open MetaTrader 5 and compile the EA in MetaEditor.
3. Attach the EA to an XAUUSD (or XAUUSDm) chart.
4. Ensure AutoTrading is enabled.
5. Keep the chart on any timeframe (the EA internally uses M5 and M15 data).

## Notes
- VWAP is calculated using a daily reset on server time and uses tick volume for weighting.
- The EA trades only on new M5 bars to avoid duplicate signals.
