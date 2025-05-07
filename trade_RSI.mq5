//+------------------------------------------------------------------+
//|                                                  RSI_Trader_EA.mq5 |
//|                                            Developed by Claude 3.7 |
//|                                                                    |
//| Description: Expert Advisor that trades based on RSI indicator     |
//| - Buy when RSI goes below 30 (oversold)                            |
//| - Sell when RSI goes above 70 (overbought)                         |
//+------------------------------------------------------------------+
#property copyright "Claude 3.7"
#property version   "1.00"
#property strict

// Input parameters
input int      RSI_Period          = 14;       // RSI Period
input double   RSI_UpperLevel      = 70;       // RSI Upper Level (Overbought)
input double   RSI_LowerLevel      = 30;       // RSI Lower Level (Oversold)
input double   LotSize             = 0.1;      // Trading lot size
input int      StopLoss            = 100;      // Stop Loss in points
input int      TakeProfit          = 200;      // Take Profit in points
input int      Magic               = 123456;   // EA Magic Number
input bool     CloseOnOppositeSignal = true;   // Close position on opposite signal

// Global variables
int rsiHandle;       // RSI indicator handle
double rsiBuffer[];  // RSI values buffer
int barCount;        // Number of bars to calculate

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Create RSI indicator handle
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);

// Check if indicator was created successfully
   if(rsiHandle == INVALID_HANDLE)
     {
      Print("Error creating RSI indicator");
      return(INIT_FAILED);
     }

// Set buffer as series to access in correct order
   ArraySetAsSeries(rsiBuffer, true);

// Initialize variables
   barCount = 3; // We need a few bars to analyze trends

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Release indicator handle
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Update indicator values
   if(CopyBuffer(rsiHandle, 0, 0, barCount, rsiBuffer) < barCount)
     {
      Print("Error copying RSI buffer");
      return;
     }

// Check if we already have a position
   bool haveLongPosition = false;
   bool haveShortPosition = false;
   int positionsCount = PositionsTotal();

   for(int i = 0; i < positionsCount; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      // Check if position belongs to this EA
      if(PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      // Check if position is on the current symbol
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Check position type
      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         haveLongPosition = true;
      else
         if(type == POSITION_TYPE_SELL)
            haveShortPosition = true;
     }

// Current RSI value
   double currentRSI = rsiBuffer[0];
   double previousRSI = rsiBuffer[1];

// RSI overbought signal (Above upper level)
   bool sellSignal = (currentRSI > RSI_UpperLevel && previousRSI <= RSI_UpperLevel);

// RSI oversold signal (Below lower level)
   bool buySignal = (currentRSI < RSI_LowerLevel && previousRSI >= RSI_LowerLevel);

// Close positions on opposite signals if enabled
   if(CloseOnOppositeSignal)
     {
      if(sellSignal && haveLongPosition)
         CloseAllPositions(POSITION_TYPE_BUY);

      if(buySignal && haveShortPosition)
         CloseAllPositions(POSITION_TYPE_SELL);
     }

// Open new positions
   if(buySignal && !haveLongPosition)
      OpenBuyPosition();

   if(sellSignal && !haveShortPosition)
      OpenSellPosition();
  }

//+------------------------------------------------------------------+
//| Function to open a buy position                                  |
//+------------------------------------------------------------------+
void OpenBuyPosition()
  {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLossPrice = (StopLoss > 0) ? price - StopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT) : 0;
   double takeProfitPrice = (TakeProfit > 0) ? price + TakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT) : 0;

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = price;
   request.sl = stopLossPrice;
   request.tp = takeProfitPrice;
   request.deviation = 10;
   request.magic = Magic;
   request.comment = "RSI BUY";
   request.type_filling = ORDER_FILLING_FOK;

   bool success = OrderSend(request, result);

   if(success)
      Print("Buy order opened successfully: ", result.order, ", retcode: ", result.retcode);
   else
      Print("Failed to open buy order: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| Function to open a sell position                                 |
//+------------------------------------------------------------------+
void OpenSellPosition()
  {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLossPrice = (StopLoss > 0) ? price + StopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT) : 0;
   double takeProfitPrice = (TakeProfit > 0) ? price - TakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT) : 0;

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = price;
   request.sl = stopLossPrice;
   request.tp = takeProfitPrice;
   request.deviation = 10;
   request.magic = Magic;
   request.comment = "RSI SELL";
   request.type_filling = ORDER_FILLING_FOK;

   bool success = OrderSend(request, result);

   if(success)
      Print("Sell order opened successfully: ", result.order, ", retcode: ", result.retcode);
   else
      Print("Failed to open sell order: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| Function to close all positions of a given type                  |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
  {
   int positionsCount = PositionsTotal();

// Loop through positions in reverse order (to avoid issues when removing items)
   for(int i = positionsCount - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      // Check if position belongs to this EA
      if(PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      // Check if position is on the current symbol
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Check position type
      if(PositionGetInteger(POSITION_TYPE) != posType)
         continue;

      // Close the position
      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL;
      request.position = ticket;
      request.symbol = _Symbol;
      request.volume = PositionGetDouble(POSITION_VOLUME);

      if(posType == POSITION_TYPE_BUY)
        {
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         request.type = ORDER_TYPE_SELL;
        }
      else
        {
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         request.type = ORDER_TYPE_BUY;
        }

      request.deviation = 10;
      request.magic = Magic;
      request.comment = "Close by RSI signal";
      request.type_filling = ORDER_FILLING_FOK;

      bool success = OrderSend(request, result);

      if(success)
         Print("Position closed successfully: ", ticket, ", retcode: ", result.retcode);
      else
         Print("Failed to close position: ", GetLastError());
     }
  }
//+------------------------------------------------------------------+
