-- DROP TABLE IF EXISTS `student`;
CREATE TABLE `student` (
  -- Primary & Identifiers
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `studentIdNumber` varchar(50) DEFAULT NULL,
  
  -- Core Fields
  `name` varchar(255) NOT NULL,
  `surname` varchar(255) NOT NULL,
  `regNumber` varchar(50) NOT NULL,
  `class` varchar(50) NOT NULL,
  `gender` enum('Male','Female') NOT NULL,
  `age` date NOT NULL,
  `phoneNumber` varchar(20) NOT NULL,
  `paymentStatus` varchar(255) NOT NULL,
  
  -- Attendance Fields
  `isPresent` tinyint(1) DEFAULT 1,
  `presentDates` json DEFAULT NULL,
  `absentDates` json DEFAULT NULL,
  
  -- Demographic Fields
  `physicalAddress` text DEFAULT NULL,
  `formerSchool` varchar(255) DEFAULT NULL,
  `religion` varchar(100) DEFAULT NULL,
  `denomination` varchar(100) DEFAULT NULL,
  `nationalIdNumber` varchar(50) DEFAULT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `district` varchar(100) DEFAULT NULL,
  `previousSchoolPerformanceResults` text DEFAULT NULL,
  `enrollmentStatus` enum('Enrolled','Not Enrolled') DEFAULT 'Not Enrolled',
  
  -- Emergency Contact
  `emergencyContactName` varchar(255) DEFAULT NULL,
  `emergencyContactNumber` varchar(20) DEFAULT NULL,
  
  -- Health Fields ✅ NEW
  `healthStatus` varchar(255) DEFAULT NULL, -- ✅ Fixed from 'healthStauts'
  `healthDetailedInformation` text DEFAULT NULL, -- ✅ NEW FIELD
  
  -- Academic Fields
  `termId` varchar(250) DEFAULT NULL,
  `terms` json DEFAULT NULL,
  
  -- Exceptions ✅ NEW
  `exceptions` json DEFAULT NULL, -- ✅ Changed from TEXT to JSON
  
  -- New Comer Fields
  `isNewComer` tinyint(1) DEFAULT 0,
  `isNewComerFrom` datetime DEFAULT NULL,
  `isNewComerUntil` datetime DEFAULT NULL,
  
  -- Sync & Audit Fields
  `operationType` varchar(200) DEFAULT 'none',
  `lastModified` datetime(6) DEFAULT current_timestamp(6),
  `syncStatus` tinyint(1) DEFAULT 0,
  `createdAt` timestamp NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  
  -- Foreign Keys
  `fid` int(11) DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_studentIdNumber` (`studentIdNumber`),
  UNIQUE KEY `uk_regNumber` (`regNumber`),
  KEY `idx_name` (`name`, `surname`),
  KEY `idx_class` (`class`),
  KEY `idx_syncStatus` (`syncStatus`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;