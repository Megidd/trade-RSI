//+------------------------------------------------------------------+
//|                                                RSI_Trading_EA.mq5 |
//|                             Copyright 2025, Your Name or Company |
//|                                             https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name or Company"
#property link      "https://www.example.com"
#property version   "1.00"
#property description "Simple RSI Overbought/Oversold Trading EA"

//--- input parameters
input int    InpPeriodRSI = 14;     // RSI Period
input int    InpLevelBuy  = 30;      // RSI Buy Level
input int    InpLevelSell = 70;      // RSI Sell Level
input double InpLotSize   = 0.1;     // Trading Lot Size
input int    InpMagic     = 12345;   // Magic Number

//--- indicator handle
int rsi_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create RSI indicator handle
   rsi_handle = iRSI(Symbol(),      // Current symbol
                     Period(),      // Current timeframe
                     InpPeriodRSI,  // RSI period
                     PRICE_CLOSE);  // Price type (Close price)

//--- check if handle creation failed
   if(rsi_handle == INVALID_HANDLE)
     {
      Print("Failed to create RSI indicator handle. Error code: ", GetLastError());
      return(INIT_FAILED);
     }

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }
//+------------------------------------------------------------------+
//| New tick event                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check for open positions
   if(PositionsTotal() > 0)
     {
      // You might add logic here to manage open positions (e.g., close on opposite signal)
      // For this simple example, we won't open new positions if one is already open.
      return;
     }

//--- variables to store RSI values
   double rsi_values[];

//--- copy RSI values to the array (get the last 2 values)
   if(CopyBuffer(rsi_handle, 0, 1, 2, rsi_values) <= 0) // Copy 2 values starting from bar 1 (current bar is 0)
     {
      Print("Failed to copy RSI buffer. Error code: ", GetLastError());
      return;
     }

   // rsi_values[0] is the RSI value of the previous completed bar
   // rsi_values[1] is the RSI value of the current (incomplete) bar - be cautious using this for signals

   double current_rsi = rsi_values[0]; // Use the RSI of the last completed bar for signal

//--- trading logic
   // Buy signal: RSI crosses below the buy level
   // We check if the previous bar's RSI was above or equal to the level
   // and the current bar's RSI is below the level.
   if(rsi_values[1] >= InpLevelBuy && current_rsi < InpLevelBuy)
     {
      // Check if we don't have any open buy positions with the same magic number
      if (!HasOpenPosition(ORDER_TYPE_BUY, InpMagic))
      {
          // Send a buy order
          TradeRequest request = {};
          TradeResult result = {};

          request.action = TRADE_ACTION_DEAL;
          request.symbol = Symbol();
          request.volume = InpLotSize;
          request.type = ORDER_TYPE_BUY;
          request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // Buy at Ask price
          request.deviation = 10; // Allowable price deviation in points
          request.magic = InpMagic;
          request.comment = "RSI Buy Signal";

          // Optional: Set Stop Loss and Take Profit
          // request.sl = NormalizeDouble(request.price - 100 * _Point, _Digits); // Example SL (100 points below)
          // request.tp = NormalizeDouble(request.price + 200 * _Point, _Digits); // Example TP (200 points above)

          if(OrderSend(request, result))
            {
             PrintFormat("Buy order sent. Result: %d", result.retcode);
            }
          else
            {
             PrintFormat("Failed to send buy order. Error: %d", GetLastError());
            }
      }
     }

   // Sell signal: RSI crosses above the sell level
   // We check if the previous bar's RSI was below or equal to the level
   // and the current bar's RSI is above the level.
   if(rsi_values[1] <= InpLevelSell && current_rsi > InpLevelSell)
     {
       // Check if we don't have any open sell positions with the same magic number
       if (!HasOpenPosition(ORDER_TYPE_SELL, InpMagic))
       {
          // Send a sell order
          TradeRequest request = {};
          TradeResult result = {};

          request.action = TRADE_ACTION_DEAL;
          request.symbol = Symbol();
          request.volume = InpLotSize;
          request.type = ORDER_TYPE_SELL;
          request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID); // Sell at Bid price
          request.deviation = 10; // Allowable price deviation in points
          request.magic = InpMagic;
          request.comment = "RSI Sell Signal";

          // Optional: Set Stop Loss and Take Profit
          // request.sl = NormalizeDouble(request.price + 100 * _Point, _Digits); // Example SL (100 points above)
          // request.tp = NormalizeDouble(request.price - 200 * _Point, _Digits); // Example TP (200 points below)

          if(OrderSend(request, result))
            {
             PrintFormat("Sell order sent. Result: %d", result.retcode);
            }
          else
            {
             PrintFormat("Failed to send sell order. Error: %d", GetLastError());
            }
       }
     }
  }

//+------------------------------------------------------------------+
//| Custom function to check for open positions with a specific type |
//| and magic number                                                 |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_ORDER_TYPE type, int magic)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong position_ticket = PositionGetTicket(i);
        if(position_ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
               PositionGetInteger(POSITION_MAGIC) == magic &&
               PositionGetInteger(POSITION_TYPE) == type)
            {
                return true; // Found an open position of the specified type and magic number
            }
        }
    }
    return false; // No open position of the specified type and magic number found
}

//+------------------------------------------------------------------+