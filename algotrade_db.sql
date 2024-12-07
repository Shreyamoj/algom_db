-- Creating the database for the trading platform
CREATE DATABASE IF NOT EXISTS algo_trading_platform;
USE algo_trading_platform;

-- ============================
-- 1. TABLE CREATION
-- ============================

-- Table to store stock metadata
CREATE TABLE IF NOT EXISTS stocks (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    sector VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Table to store users
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    hashed_password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to store historical and live stock data
CREATE TABLE IF NOT EXISTS stock_data (
    data_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    time TIME NOT NULL,
    open_price DECIMAL(15, 2) NOT NULL,
    high_price DECIMAL(15, 2) NOT NULL,
    low_price DECIMAL(15, 2) NOT NULL,
    close_price DECIMAL(15, 2) NOT NULL,
    volume BIGINT NOT NULL,
    moving_average_50 DECIMAL(15, 2),
    moving_average_200 DECIMAL(15, 2),
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE(stock_id, date, time)
);



-- Table to store user trading strategies
CREATE TABLE IF NOT EXISTS strategies (
    strategy_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parameters JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Table to log trades
CREATE TABLE IF NOT EXISTS trades (
    trade_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    strategy_id INT NOT NULL,
    stock_id INT NOT NULL,
    trade_type ENUM('BUY', 'SELL') NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(15, 2) NOT NULL,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    profit_loss DECIMAL(15, 2) DEFAULT 0.00,
    FOREIGN KEY (strategy_id) REFERENCES strategies(strategy_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- Table to log system activities and errors
CREATE TABLE IF NOT EXISTS system_logs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    log_type ENUM('INFO', 'ERROR', 'WARNING') NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to track stock watchlists
CREATE TABLE IF NOT EXISTS watchlists (
    watchlist_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    stock_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE(user_id, stock_id)
);

-- Table to store scheduled tasks
CREATE TABLE IF NOT EXISTS scheduled_tasks (
    task_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    task_name VARCHAR(100) NOT NULL,
    status ENUM('PENDING', 'RUNNING', 'COMPLETED', 'FAILED') DEFAULT 'PENDING',
    scheduled_time TIMESTAMP NOT NULL,
    completed_time TIMESTAMP NULL,
    logs TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
DELIMITER $$

CREATE TRIGGER calculate_indicators_and_execute_strategy
AFTER INSERT ON stock_data
FOR EACH ROW
BEGIN
    -- Calculate 50-period moving average (Short-term MA)
    SET @ma_50 = (
        SELECT AVG(close_price)
        FROM (
            SELECT close_price
            FROM stock_data
            WHERE stock_id = NEW.stock_id
            ORDER BY date DESC, time DESC
            LIMIT 50
        ) AS recent_50
    );

    -- Calculate 200-period moving average (Long-term MA)
    SET @ma_200 = (
        SELECT AVG(close_price)
        FROM (
            SELECT close_price
            FROM stock_data
            WHERE stock_id = NEW.stock_id
            ORDER BY date DESC, time DESC
            LIMIT 200
        ) AS recent_200
    );

    -- Calculate RSI (Relative Strength Index) for 14 periods
    SET @rsi = (
        SELECT CASE
                WHEN COUNT(CASE WHEN close_price > prev_close THEN 1 END) > 0
                THEN AVG(close_price - prev_close) / AVG(prev_close - close_price)
                ELSE 0
               END AS rsi
        FROM (
            SELECT close_price, 
                   LAG(close_price) OVER (ORDER BY date DESC) AS prev_close
            FROM stock_data
            WHERE stock_id = NEW.stock_id
            ORDER BY date DESC, time DESC
            LIMIT 14
        ) AS price_changes
    );

    -- Execute trading strategy: Buy if short-term MA crosses above long-term MA and RSI is below 30 (indicating oversold conditions)
    IF @ma_50 > @ma_200 AND @rsi < 30 THEN
        -- Perform Buy action (You can add more CRUD operations to insert trade actions into a trades table)
        INSERT INTO trades (stock_id, action, trade_type, trade_time)
        VALUES (NEW.stock_id, 'BUY', 'Long', NOW());
    END IF;

    -- Execute trading strategy: Sell if short-term MA crosses below long-term MA and RSI is above 70 (indicating overbought conditions)
    IF @ma_50 < @ma_200 AND @rsi > 70 THEN
        -- Perform Sell action
        INSERT INTO trades (stock_id, action, trade_type, trade_time)
        VALUES (NEW.stock_id, 'SELL', 'Short', NOW());
    END IF;

    -- Update the stock_data table with the calculated moving averages and RSI values
    UPDATE stock_data
    SET moving_average_50 = @ma_50,
        moving_average_200 = @ma_200,
        rsi = @rsi
    WHERE data_id = NEW.data_id;

END$$

DELIMITER ;

-- ============================
-- 3. CRUD OPERATIONS
-- ============================

-- Add a new stock
-- Insert NIFTY 50 stocks into the stocks table
INSERT INTO stocks (symbol, name, sector) VALUES
('ADANIENT', 'Adani Enterprises', 'Conglomerate'),
('ADANIPORTS', 'Adani Ports and SEZ', 'Transport Infrastructure'),
('APOLLOHOSP', 'Apollo Hospitals', 'Healthcare'),
('ASIANPAINT', 'Asian Paints', 'Consumer Goods'),
('AXISBANK', 'Axis Bank', 'Banking'),
('BAJAJ-AUTO', 'Bajaj Auto', 'Automobile'),
('BAJFINANCE', 'Bajaj Finance', 'Financial Services'),
('BAJAJFINSV', 'Bajaj Finserv', 'Financial Services'),
('BPCL', 'Bharat Petroleum Corporation Limited', 'Oil & Gas'),
('BHARTIARTL', 'Bharti Airtel', 'Telecommunications'),
('BRITANNIA', 'Britannia Industries', 'Consumer Goods'),
('CIPLA', 'Cipla', 'Pharmaceuticals'),
('COALINDIA', 'Coal India', 'Mining'),
('DIVISLAB', 'Divi’s Laboratories', 'Pharmaceuticals'),
('DRREDDY', 'Dr. Reddy’s Laboratories', 'Pharmaceuticals'),
('EICHERMOT', 'Eicher Motors', 'Automobile'),
('GRASIM', 'Grasim Industries', 'Conglomerate'),
('HCLTECH', 'HCL Technologies', 'IT Services'),
('HDFC', 'HDFC Ltd.', 'Financial Services'),
('HDFCBANK', 'HDFC Bank', 'Banking'),
('HDFCLIFE', 'HDFC Life Insurance', 'Insurance'),
('HEROMOTOCO', 'Hero MotoCorp', 'Automobile'),
('HINDALCO', 'Hindalco Industries', 'Metals'),
('HINDUNILVR', 'Hindustan Unilever', 'Consumer Goods'),
('ICICIBANK', 'ICICI Bank', 'Banking'),
('INDUSINDBK', 'IndusInd Bank', 'Banking'),
('INFY', 'Infosys', 'IT Services'),
('ITC', 'ITC Ltd.', 'Conglomerate'),
('JSWSTEEL', 'JSW Steel', 'Metals'),
('KOTAKBANK', 'Kotak Mahindra Bank', 'Banking'),
('LT', 'Larsen & Toubro', 'Infrastructure'),
('M&M', 'Mahindra & Mahindra', 'Automobile'),
('MARUTI', 'Maruti Suzuki', 'Automobile'),
('NTPC', 'NTPC Ltd.', 'Power'),
('ONGC', 'Oil and Natural Gas Corporation', 'Oil & Gas'),
('POWERGRID', 'Power Grid Corporation', 'Power'),
('RELIANCE', 'Reliance Industries', 'Conglomerate'),
('SBILIFE', 'SBI Life Insurance', 'Insurance'),
('SBIN', 'State Bank of India', 'Banking'),
('SUNPHARMA', 'Sun Pharmaceuticals', 'Pharmaceuticals'),
('TATACONSUM', 'Tata Consumer Products', 'Consumer Goods'),
('TATAMOTORS', 'Tata Motors', 'Automobile'),
('TATASTEEL', 'Tata Steel', 'Metals'),
('TCS', 'Tata Consultancy Services', 'IT Services'),
('TECHM', 'Tech Mahindra', 'IT Services'),
('TITAN', 'Titan Company', 'Consumer Goods'),
('ULTRACEMCO', 'UltraTech Cement', 'Cement'),
('UPL', 'UPL Ltd.', 'Chemicals'),
('WIPRO', 'Wipro', 'IT Services');

-- Add a new user
INSERT INTO users (username, email, hashed_password) VALUES
('Bappa', 'bappa844@gmail.com', 'hashed_password_placeholder');

-- Add a new strategy
INSERT INTO strategies (user_id, name, description, parameters) VALUES
(1, 'Mean Reversion', 'Buy when RSI < 30, sell when RSI > 70', '{"RSI_low": 30, "RSI_high": 70}');

-- Fetch all stocks
SELECT * FROM stocks;

-- Update stock details
UPDATE stocks SET sector = 'Finance' WHERE symbol = 'NIFTY';

-- Delete a stock (cascades data in related tables)
DELETE FROM stocks WHERE symbol = 'AAPL';

-- ============================
-- 4. SAMPLE BACKTESTING
-- ============================

-- Calculate profit/loss for a backtesting strategy
SELECT t.strategy_id, s.name AS strategy_name, SUM(t.profit_loss) AS total_profit_loss
FROM trades t
JOIN strategies s ON t.strategy_id = s.strategy_id
WHERE t.executed_at BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY t.strategy_id;

-- Fetch stock performance summary
SELECT stock_id, MAX(high_price) AS highest_price, MIN(low_price) AS lowest_price
FROM stock_data
WHERE date BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY stock_id;

-- ============================
-- 5. LOGGING SYSTEM
-- ============================

-- Insert a log entry
INSERT INTO system_logs (log_type, message) VALUES ('INFO', 'Stock data fetched successfully.');

-- Fetch all logs
SELECT * FROM system_logs;
