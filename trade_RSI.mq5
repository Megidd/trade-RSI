//+------------------------------------------------------------------+
//|                                                RSI_Trading_EA.mq5 |
//|                             Copyright 2025, Your Name or Company |
//|                                             https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name or Company"
#property link      "https://www.example.com"
#property version   "1.01" // Updated version
#property description "Simple RSI Overbought/Oversold Trading EA with Closing Logic"

//--- input parameters
input int    InpPeriodRSI = 14;     // RSI Period
input int    InpLevelBuy  = 30;      // RSI Buy Level
input int    InpLevelSell = 70;      // RSI Sell Level
input double InpLotSize   = 0.1;     // Trading Lot Size
input int    InpMagic     = 12345;   // Magic Number
input int    InpStopLoss  = 0;       // Stop Loss in points (0 = disabled)
input int    InpTakeProfit= 0;       // Take Profit in points (0 = disabled)


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
//--- variables to store RSI values
   double rsi_values[];

//--- copy RSI values to the array (get the last 2 values)
   // We need at least 2 bars of data for the cross logic (previous and current completed)
   // CopyBuffer(handle, buffer_index, start_index, count, target_array)
   // start_index 0 is the current incomplete bar, 1 is the last completed bar, 2 is the bar before that.
   if(CopyBuffer(rsi_handle, 0, 1, 2, rsi_values) <= 0) // Copy 2 values starting from bar 1 (last completed bar)
     {
      // If CopyBuffer fails for the last completed bar, it might be due to insufficient history
      // or other issues. Check GetLastError().
      if(GetLastError() != ERR_NO_HISTORY) // Ignore "no history" error, it might resolve on next tick
      {
         Print("Failed to copy RSI buffer. Error code: ", GetLastError());
      }
      return;
     }

   // Ensure we have at least 2 values copied for the cross check
   if(ArraySize(rsi_values) < 2)
   {
       // Not enough data yet, wait for more bars to form
       return;
   }


   double rsi_current_bar   = rsi_values[0]; // RSI value of the last completed bar (index 1 from CopyBuffer(..., 1, ...))
   double rsi_previous_bar  = rsi_values[1]; // RSI value of the bar before the last completed bar (index 2 from CopyBuffer(..., 1, ...))


//--- Trading Logic: Check for signals and manage positions

   // --- Check for Buy Signal ---
   // Buy signal: RSI crosses below the buy level (previous bar >= level, current bar < level)
   if(rsi_previous_bar >= InpLevelBuy && rsi_current_bar < InpLevelBuy)
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

          // Set Stop Loss and Take Profit if enabled
          if(InpStopLoss > 0)
              request.sl = NormalizeDouble(request.price - InpStopLoss * _Point, _Digits);
          if(InpTakeProfit > 0)
              request.tp = NormalizeDouble(request.price + InpTakeProfit * _Point, _Digits);

          if(OrderSend(request, result))
            {
             PrintFormat("Buy order sent. Ticket: %I64u, Result: %d", result.order, result.retcode);
            }
          else
            {
             PrintFormat("Failed to send buy order. Error: %d", GetLastError());
            }
      }
     }

   // --- Check for Sell Signal ---
   // Sell signal: RSI crosses above the sell level (previous bar <= level, current bar > level)
   if(rsi_previous_bar <= InpLevelSell && rsi_current_bar > InpLevelSell)
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

          // Set Stop Loss and Take Profit if enabled
          if(InpStopLoss > 0)
              request.sl = NormalizeDouble(request.price + InpStopLoss * _Point, _Digits);
          if(InpTakeProfit > 0)
              request.tp = NormalizeDouble(request.price - InpTakeProfit * _Point, _Digits);


          if(OrderSend(request, result))
            {
             PrintFormat("Sell order sent. Ticket: %I64u, Result: %d", result.order, result.retcode);
            }
          else
            {
             PrintFormat("Failed to send sell order. Error: %d", GetLastError());
            }
       }
     }

    // --- Check for Closing Positions ---
    // Iterate through all open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--) // Loop backwards in case positions are closed
    {
        ulong position_ticket = PositionGetTicket(i);
        if(position_ticket > 0)
        {
            // Select the position by ticket
            if(PositionSelectByTicket(position_ticket))
            {
                // Check if the position belongs to this EA and symbol
                if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
                   PositionGetInteger(POSITION_MAGIC) == InpMagic)
                {
                    long position_type = PositionGetInteger(POSITION_TYPE);

                    // Close Buy positions when RSI crosses above the sell level
                    if(position_type == POSITION_TYPE_BUY)
                    {
                        // Close signal: RSI crosses above the sell level (previous bar <= level, current bar > level)
                        if(rsi_previous_bar <= InpLevelSell && rsi_current_bar > InpLevelSell)
                        {
                            TradeRequest request = {};
                            TradeResult result = {};

                            request.action = TRADE_ACTION_DEAL;
                            request.position = position_ticket; // Specify the position to close
                            request.volume = PositionGetDouble(POSITION_VOLUME); // Close the full volume
                            request.type = ORDER_TYPE_SELL; // To close a BUY, send a SELL deal
                            request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID); // Close at Bid price
                            request.deviation = 10;
                            request.magic = InpMagic;
                            request.comment = "RSI Close Buy Signal";

                            if(OrderSend(request, result))
                            {
                                PrintFormat("Close Buy order sent for ticket %I64u. Result: %d", position_ticket, result.retcode);
                            }
                            else
                            {
                                PrintFormat("Failed to send Close Buy order for ticket %I64u. Error: %d", position_ticket, GetLastError());
                            }
                        }
                    }
                    // Close Sell positions when RSI crosses below the buy level
                    else if(position_type == POSITION_TYPE_SELL)
                    {
                        // Close signal: RSI crosses below the buy level (previous bar >= level, current bar < level)
                        if(rsi_previous_bar >= InpLevelBuy && rsi_current_bar < InpLevelBuy)
                        {
                            TradeRequest request = {};
                            TradeResult result = {};

                            request.action = TRADE_ACTION_DEAL;
                            request.position = position_ticket; // Specify the position to close
                            request.volume = PositionGetDouble(POSITION_VOLUME); // Close the full volume
                            request.type = ORDER_TYPE_BUY; // To close a SELL, send a BUY deal
                            request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // Close at Ask price
                            request.deviation = 10;
                            request.magic = InpMagic;
                            request.comment = "RSI Close Sell Signal";

                            if(OrderSend(request, result))
                            {
                                PrintFormat("Close Sell order sent for ticket %I64u. Result: %d", position_ticket, result.retcode);
                            }
                            else
                            {
                                PrintFormat("Failed to send Close Sell order for ticket %I64u. Error: %d", position_ticket, GetLastError());
                            }
                        }
                    }
                }
            }
            else
            {
                 PrintFormat("Failed to select position with ticket %I64u. Error: %d", position_ticket, GetLastError());
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
            // Select the position to access its properties
            if(PositionSelectByTicket(position_ticket))
            {
                if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
                   PositionGetInteger(POSITION_MAGIC) == magic &&
                   PositionGetInteger(POSITION_TYPE) == type)
                {
                    return true; // Found an open position of the specified type and magic number
                }
            }
             else
            {
                 PrintFormat("Failed to select position with ticket %I64u in HasOpenPosition. Error: %d", position_ticket, GetLastError());
            }
        }
    }
    return false; // No open position of the specified type and magic number found
}

//+------------------------------------------------------------------+