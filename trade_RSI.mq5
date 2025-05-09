//+------------------------------------------------------------------+
//|                                   RSI_Trader_EA_with_News_Filter.mq5 |
//|                                            Developed by Claude 3.7 |
//|                                                                    |
//| Description: Expert Advisor that trades based on RSI indicator     |
//| - Buy when RSI goes below 30 (oversold)                            |
//| - Sell when RSI goes above 70 (overbought)                         |
//| - Includes news filter to avoid trading during high-impact news    |
//+------------------------------------------------------------------+
#property copyright "Claude 3.7"
#property version   "1.10"
#property strict

// Input parameters
input int      RSI_Period          = 14;       // RSI Period
input double   RSI_UpperLevel      = 70;       // RSI Upper Level (Overbought)
input double   RSI_LowerLevel      = 30;       // RSI Lower Level (Oversold)
input double   LotSize             = 0.1;      // Trading lot size
input int      StopLoss            = 100;      // Stop Loss in points (0 = disabled)
input int      TakeProfit          = 200;      // Take Profit in points (0 = disabled)
input int      Magic               = 123456;   // EA Magic Number
input bool     CloseOnOppositeSignal = true;   // Close position on opposite signal

// News filter parameters
input bool     AvoidNews           = true;     // Avoid trading during news events
input int      MinutesBeforeNews   = 60;       // Minutes before news to stop trading
input int      MinutesAfterNews    = 60;       // Minutes after news to resume trading
input bool     CloseOnNewsApproach = false;    // Close positions when news is approaching

// Days and times to check for regular news events (central bank announcements, NFP, etc.)
input bool     Monday_News         = false;    // Check for news on Monday
input bool     Tuesday_News        = false;    // Check for news on Tuesday
input bool     Wednesday_News      = true;     // Check for news on Wednesday (FOMC typical day)
input bool     Thursday_News       = false;    // Check for news on Thursday
input bool     Friday_News         = true;     // Check for news on Friday (NFP typical day)

// News times (hour and minute in server time)
input int      News1_Hour          = 14;       // News event 1 - Hour (server time)
input int      News1_Minute        = 30;       // News event 1 - Minute
input int      News2_Hour          = 8;        // News event 2 - Hour (server time)
input int      News2_Minute        = 30;       // News event 2 - Minute

// Global variables
int rsiHandle;       // RSI indicator handle
double rsiBuffer[];  // RSI values buffer
int barCount;        // Number of bars to calculate
bool isNewsTime;     // Flag indicating if we're around news time

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

// Check for news right at startup
   isNewsTime = CheckNewsTime();
   if(isNewsTime)
      Print("EA started during news time window - trading halted until news period ends");
   else
      Print("EA started during normal trading period");

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
// Check for news events
   bool wasNewsTime = isNewsTime;
   isNewsTime = CheckNewsTime();

// If we just entered news time and need to close positions
   if(!wasNewsTime && isNewsTime && CloseOnNewsApproach && AvoidNews)
     {
      Print("News approaching - closing all positions");
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      return;
     }

// Skip trading logic if it's news time
   if(isNewsTime && AvoidNews)
     {
      // You can add additional visualization or logging here if needed
      return;
     }

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
//| Check if current time is near a scheduled news event             |
//+------------------------------------------------------------------+
bool CheckNewsTime()
  {
// If news filter is disabled, always return false
   if(!AvoidNews)
      return false;

// Get current server time
   MqlDateTime serverTime;
   TimeToStruct(TimeCurrent(), serverTime);

// Check if current day is a news day
   if((serverTime.day_of_week == 1 && !Monday_News) ||
      (serverTime.day_of_week == 2 && !Tuesday_News) ||
      (serverTime.day_of_week == 3 && !Wednesday_News) ||
      (serverTime.day_of_week == 4 && !Thursday_News) ||
      (serverTime.day_of_week == 5 && !Friday_News) ||
      (serverTime.day_of_week == 0 || serverTime.day_of_week == 6)) // Weekend
      return false;

// Convert current time to minutes
   int currentMinutes = serverTime.hour * 60 + serverTime.min;

// Convert news times to minutes
   int news1Minutes = News1_Hour * 60 + News1_Minute;
   int news2Minutes = News2_Hour * 60 + News2_Minute;

// Check if we're in a news window for news 1
   if(currentMinutes >= (news1Minutes - MinutesBeforeNews) &&
      currentMinutes <= (news1Minutes + MinutesAfterNews))
      return true;

// Check if we're in a news window for news 2
   if(currentMinutes >= (news2Minutes - MinutesBeforeNews) &&
      currentMinutes <= (news2Minutes + MinutesAfterNews))
      return true;

// Not in any news window
   return false;
  }

//+------------------------------------------------------------------+
//| Function to open a buy position                                  |
//+------------------------------------------------------------------+
void OpenBuyPosition()
  {
// Double check we're not in news time (safety check)
   if(isNewsTime && AvoidNews)
      return;

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
// Double check we're not in news time (safety check)
   if(isNewsTime && AvoidNews)
      return;

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
//+------------------------------------------------------------------+
