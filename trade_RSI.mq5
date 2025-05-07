//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, MetaQuotes Ltd."
#property link        "https://www.mql5.com"
#property version    "1.00"
#property description "Simple RSI Trading Strategy"

#include <Trade\Trade.mqh>

//--- Input parameters
input int RSIPeriod = 14;       // Period for RSI calculation
input int OverboughtLevel = 70; // RSI level to consider as overbought
input int OversoldLevel = 30;   // RSI level to consider as oversold
input double TradeVolume = 0.01; // Trade volume in lots
input int MagicNumber = 12345;  // Magic number for the EA

//--- Global instance of the trade class
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize the trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(5); // Slippage control in points
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Order filling type

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Cleanup if needed
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Get the RSI value
   double rsiValue = iRSI(Symbol(), Period(), RSIPeriod, PRICE_CLOSE);

//--- Check for sell condition
   if(rsiValue > OverboughtLevel)
     {
      //--- Check if there are any open buy positions
      if(PositionsTotal() > 0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
              {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                 {
                  //--- Close the buy position
                  trade.PositionClose(ticket);
                  Print("Buy position closed due to RSI overbought condition.");
                 }
              }
           }
        }

      //--- Open a sell position if no sell position is open
      if(PositionsTotal() == 0 || !IsExistingPosition(POSITION_TYPE_SELL))
        {
         double price = SymbolInfoDouble(Symbol(), SYMBOL_BID); // Sell at Bid price
         ulong ticket = trade.Sell(TradeVolume, _Symbol, price);
         if(ticket > 0)
            Print("Sell order opened at ", SymbolInfoDouble(_Symbol, SYMBOL_BID), " with RSI ", rsiValue);
         else
            Print("Error opening sell order: ", trade.ResultRetcodeDescription());
        }
     }
//--- Check for buy condition
   else
      if(rsiValue < OversoldLevel)
        {
         //--- Check if there are any open sell positions
         if(PositionsTotal() > 0)
           {
            for(int i = PositionsTotal() - 1; i >= 0; i--)
              {
               ulong ticket = PositionGetTicket(i);
               if(PositionSelectByTicket(ticket))
                 {
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                    {
                     //--- Close the sell position
                     trade.PositionClose(ticket);
                     Print("Sell position closed due to RSI oversold condition.");
                    }
                 }
              }
           }

         //--- Open a buy position if no buy position is open
         if(PositionsTotal() == 0 || !IsExistingPosition(POSITION_TYPE_BUY))
           {
            double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // Buy at Ask price
            ulong ticket = trade.Buy(TradeVolume, _Symbol, price);
            if(ticket > 0)
               Print("Buy order opened at ", SymbolInfoDouble(_Symbol, SYMBOL_ASK), " with RSI ", rsiValue);
            else
               Print("Error opening buy order: ", trade.ResultRetcodeDescription());
           }
        }
  }

//+------------------------------------------------------------------+
//| Function to check if a position of a certain type exists        |
//+------------------------------------------------------------------+
bool IsExistingPosition(ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_TYPE) == type)
            return(true);
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
