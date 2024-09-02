#property link          "https://www.earnforex.com/metatrader-indicators/fractals-alert/"
#property version       "1.02"
#property strict
#property copyright     "EarnForex.com - 2019-2024"
#property description   "Fractals with alert."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this indicator cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 1

#include <MQLTA Utils.mqh>

enum ENUM_TRADE_SIGNAL
{
    SIGNAL_BUY = 1,    // BUY
    SIGNAL_SELL = -1,  // SELL
    SIGNAL_NEUTRAL = 0 // NEUTRAL
};

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0, // CURRENT CANDLE
    CLOSED_CANDLE = 1   // PREVIOUS CANDLE
};

input string Comment1 = "========================"; // MQLTA Fractals Alert
input string IndicatorName = "MQLTA-FRAL";          // Indicator Short Name

input string Comment2 = "========================"; // Indicator Parameters
input ENUM_CANDLE_TO_CHECK CandleToCheck = CURRENT_CANDLE; // Candle To Use For Analysis
input int BarsToScan = 500;                                // Number Of Candles To Analyze (0 = All)

input string Comment_3 = "===================="; // Notification Options
input bool EnableNotify = false;                 // Enable Notifications Feature
input bool SendAlert = true;                     // Send Alert Notification
input bool SendApp = true;                       // Send Notification to Mobile
input bool SendEmail = true;                     // Send Notification via Email
input bool AlertOnBuy = true;                    // Turn On Buy Signals
input bool AlertOnSell = true;                   // Turn On Sell Signals
input int WaitTimeNotify = 5;                    // Wait time between notifications (Seconds)
input string Comment_4 = "===================="; // Drawing Options
input bool EnableDrawArrows = true;              // Draw Signal Arrows
input int ArrowBuy = 241;                        // Buy Arrow Code
input int ArrowSell = 242;                       // Sell Arrow Code
input int ArrowSize = 3;                         // Arrow Size (1-5)
input color ArrowBuyColor = clrGreen;            // Buy Arrow Color
input color ArrowSellColor = clrRed;             // Sell Arrow Color

double Buffer[]; // Signal output for iCustom(). 1 = Buy, -1 = Sell, 0 = Neutral.
ENUM_TRADE_SIGNAL LastNotificationDirection;
datetime LastNotificationTime;
int Shift;

int OnInit(void)
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    SetIndexBuffer(0, Buffer);
    SetIndexStyle(0, DRAW_NONE);

    OnInitInitialization();

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    bool IsNewCandle = CheckIfNewCandle();

    int counted_bars = 0;
    if (prev_calculated > 0) counted_bars = prev_calculated - 1;

    if (counted_bars < 0) return -1;
    if (counted_bars > 0) counted_bars--;
    int limit = rates_total - counted_bars;
    if ((BarsToScan > 0) && (limit > BarsToScan))
    {
        limit = BarsToScan;
        if (rates_total < BarsToScan) limit = BarsToScan - 2;
        if (limit <= 0)
        {
            Print("Need more historical data.");
            return 0;
        }
    }
    if (limit > rates_total - 2) limit = rates_total - 2;

    if ((IsNewCandle) || (prev_calculated == 0))
    {
        if (EnableDrawArrows) DrawArrows(limit);
        CleanUpOldArrows();
    }

    if (EnableDrawArrows) DrawArrow(0);

    if (EnableNotify) NotifyHit();

    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

void OnInitInitialization()
{
    LastNotificationTime = TimeCurrent();
    Shift = CandleToCheck;
}

void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

datetime NewCandleTime = TimeCurrent();
bool CheckIfNewCandle()
{
    if (NewCandleTime == iTime(Symbol(), 0, 0)) return false;
    else
    {
        NewCandleTime = iTime(Symbol(), 0, 0);
        return true;
    }
}

// Check if it is a trade signal: 0 = Neutral, 1 = Buy, -1 = Sell.
ENUM_TRADE_SIGNAL IsSignal(int i)
{
    int j = i + Shift + 2;

    if (iFractals(NULL, 0, MODE_UPPER, j) > 0)
    {
        return SIGNAL_SELL;
    }
    if (iFractals(NULL, 0, MODE_LOWER, j) > 0)
    {
        return SIGNAL_BUY;
    }

    return SIGNAL_NEUTRAL;
}

datetime LastNotification = TimeCurrent() - WaitTimeNotify;
void NotifyHit()
{
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if (CandleToCheck == CLOSED_CANDLE)
    {
        if (iTime(Symbol(), Period(), 0) <= LastNotificationTime) return;
    }
    else // Current candle.
    {
        if (TimeCurrent() - LastNotificationTime < WaitTimeNotify) return; // Notifications are coming too fast.
    }
    ENUM_TRADE_SIGNAL Signal = IsSignal(0);
    if (Signal == SIGNAL_NEUTRAL)
    {
        LastNotificationDirection = Signal;
        return;
    }
    if (Signal == LastNotificationDirection) return;
    if ((Signal == SIGNAL_BUY) && (!AlertOnBuy)) return;
    if ((Signal == SIGNAL_SELL) && (!AlertOnSell)) return;
    string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + IndicatorName + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    string AlertText = IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " ";
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " - ";
    string Text = "";

    if (Signal == SIGNAL_BUY)
    {
        Text += "Bottom Fractals Formed";
    }
    else if (Signal == SIGNAL_SELL)
    {
        Text += "Top Fractals Formed";
    }

    EmailBody += Text;
    AlertText += Text;
    AppText += Text;
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    LastNotificationTime = TimeCurrent();
    LastNotificationDirection = Signal;
}

void DrawArrows(int limit)
{
    for (int i = limit - 1; i >= 1; i--)
    {
        DrawArrow(i);
    }
}

void DrawArrow(int i)
{
    RemoveArrowCurr();
    ENUM_TRADE_SIGNAL Signal = IsSignal(i);
    Buffer[i] = 0;
    if (Signal == SIGNAL_NEUTRAL) return;
    datetime ArrowDate = iTime(Symbol(), 0, i);
    string ArrowName = IndicatorName + "-ARWS-" + IntegerToString(ArrowDate);
    double ArrowPrice = 0;
    int ArrowType = 0;
    color ArrowColor = 0;
    int ArrowAnchor = 0;
    string ArrowDesc = "";
    if (Signal == SIGNAL_BUY)
    {
        ArrowPrice = iLow(Symbol(), Period(), i);
        ArrowType = ArrowBuy;
        ArrowColor = ArrowBuyColor;
        ArrowAnchor = ANCHOR_TOP;
        ArrowDesc = "BUY";
        Buffer[i] = 1;
    }
    else if (Signal == SIGNAL_SELL)
    {
        ArrowPrice = iHigh(Symbol(), Period(), i);
        ArrowType = ArrowSell;
        ArrowColor = ArrowSellColor;
        ArrowAnchor = ANCHOR_BOTTOM;
        ArrowDesc = "SELL";
        Buffer[i] = -1;
    }
    ObjectCreate(0, ArrowName, OBJ_ARROW, 0, ArrowDate, ArrowPrice);
    ObjectSetInteger(0, ArrowName, OBJPROP_COLOR, ArrowColor);
    ObjectSetInteger(0, ArrowName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, ArrowName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, ArrowName, OBJPROP_ANCHOR, ArrowAnchor);
    ObjectSetInteger(0, ArrowName, OBJPROP_ARROWCODE, ArrowType);
    ObjectSetInteger(0, ArrowName, OBJPROP_WIDTH, ArrowSize);
    ObjectSetInteger(0, ArrowName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, ArrowName, OBJPROP_BGCOLOR, ArrowColor);
    ObjectSetString(0, ArrowName, OBJPROP_TEXT, ArrowDesc);
}

void RemoveArrowCurr()
{
    datetime ArrowDate = iTime(Symbol(), 0, 0);
    string ArrowName = IndicatorName + "-ARWS-" + IntegerToString(ArrowDate);
    ObjectDelete(0, ArrowName);
    Buffer[0] = 0;
}

// Delete all arrows that are older than BarsToScan bars.
void CleanUpOldArrows()
{
    int total = ObjectsTotal(ChartID(), 0, OBJ_ARROW);
    for (int i = total - 1; i >= 0; i--)
    {
        string ArrowName = ObjectName(ChartID(), i, 0, OBJ_ARROW);
        datetime time = (datetime)ObjectGetInteger(ChartID(), ArrowName, OBJPROP_TIME);
        int bar = iBarShift(Symbol(), Period(), time);
        if ((BarsToScan > 0) && (bar >= BarsToScan)) ObjectDelete(ChartID(), ArrowName);
    }
}
//+------------------------------------------------------------------+