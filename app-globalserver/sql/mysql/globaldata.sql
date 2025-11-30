/*
 Navicat MySQL Data Transfer

 Source Server         : localhost_root2_1
 Source Server Type    : MySQL
 Source Host           : 192.168.0.106:3306
 Source Schema         : globaldata
 File Encoding         : 65001
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for alliance
-- ----------------------------
CREATE TABLE IF NOT EXISTS `alliance`  (
    `_id` bigint NOT NULL,
    `kid` int NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_alliance_kid`(`kid`) USING BTREE,
    INDEX `key_alliance_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '联盟信息表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for cachealliance
-- ----------------------------
CREATE TABLE IF NOT EXISTS `cachealliance`  (
    `_id` bigint NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_cachealliance_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '联盟缓存数据表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for dropinfo
-- ----------------------------
CREATE TABLE IF NOT EXISTS `droplimitinfo`  (
    `_id` bigint NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_droplimitinfo_id`(`_id`) USING BTREE,
    INDEX `key_droplimitinfo_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '全局掉落信息' ROW_FORMAT = Dynamic;

-- Table structure for tradeinfo
-- ----------------------------
CREATE TABLE IF NOT EXISTS `tradeinfo`  (
    `_id` bigint NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_tradeinfo_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '玩家交易信息表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for tradegoods
-- ----------------------------
CREATE TABLE IF NOT EXISTS `tradegoods`  (
    `_id` bigint NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_tradegoods_id`(`_id`) USING BTREE,
    INDEX `key_tradegoods_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '拍卖行信息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chatinfo
-- ----------------------------
CREATE TABLE IF NOT EXISTS `chatinfo`  (
    `_id` bigint NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_chatinfo_id`(`_id`) USING BTREE,
    INDEX `key_chatinfo_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '玩家聊天信息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chat
-- ----------------------------
CREATE TABLE IF NOT EXISTS `chat`  (
    `_id` char(20) NOT NULL,
    `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
    `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`_id`) USING BTREE,
    INDEX `key_chat_id`(`_id`) USING BTREE,
    INDEX `key_chat_updatetime`(`updatetime`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '聊天室信息' ROW_FORMAT = Dynamic;