-- phpMyAdmin SQL Dump
-- version 4.6.4
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Sep 25, 2016 at 10:17 AM
-- Server version: 5.6.33
-- PHP Version: 7.0.11

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `currentcost_v2`
--

-- --------------------------------------------------------

--
-- Table structure for table `CurrentCostDataSamples_MySQL_Raw_Event_Stream`
--

CREATE TABLE `CurrentCostDataSamples_MySQL_Raw_Event_Stream` (
  `MYSQLTIMESTAMP` datetime DEFAULT NULL,
  `TEMP` float DEFAULT NULL,
  `SENSOR` tinyint(4) DEFAULT NULL,
  `WATT` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `CurrentCostDataSamples_MySQL_Samples`
--

CREATE TABLE `CurrentCostDataSamples_MySQL_Samples` (
  `SENSOR` tinyint(4) DEFAULT NULL,
  `TEMP` float DEFAULT NULL,
  `TIMESTAMP` bigint(20) DEFAULT NULL,
  `TIMESTAMPMYSQL` datetime DEFAULT NULL,
  `WATT` int(11) DEFAULT NULL,
  `WATTSECONDS` bigint(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
