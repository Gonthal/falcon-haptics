#pragma once

#ifndef SOCKETCLIENT_H
#define SOCKETCLIENT_H

#define _WIN32_WINNT 0x501
#define WIN32_LEAN_AND_MEAN

#include "stdafx.h"
#include "AppTypes.h"
#include <windows.h>
#include <winsock2.h>
#include <WS2tcpip.h>
#include <stdlib.h>
#include <stdio.h>
#include <vector>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <atomic>

// Need to link with Ws2_32.lib, Mswsock.lib, and AdvApi32.lib
#pragma comment (lib, "Ws2_32.lib")
#pragma comment (lib, "Mswsock.lib")
#pragma comment (lib, "AdvApi32.lib")

#define DEFAULT_BUFLEN 512
#define DEFAULT_PORT "27015"

// Helpers to convert float/double using winsock helpers available
inline uint32_t float_to_net(float v) { return htonf(v); }
inline float    net_to_float(uint32_t v) { return ntohf(v); }

inline uint64_t double_to_net(double v) { return htond(v); }
inline double   net_to_double(uint64_t v) { return ntohd(v); }

inline uint16_t short_to_net(uint16_t v) { return htons(v); }
inline uint16_t net_to_short(uint16_t v) { return ntohs(v); }

/******************************************************************/
/* THREAD-SAFE QUEUE DECLARATION & DEFINITION */
/******************************************************************/
/* Template must be defined in the header so all translation units
   can instantiate it. */
template <typename T>
class ThreadSafeQueue {
public:
	void push(T value) {
		std::lock_guard<std::mutex> lock(mutex_);
		queue_.push(std::move(value));
		cond_.notify_one();
	}
	// Blocking pop: waits until an element is available
	T pop() {
		std::unique_lock<std::mutex> lock(mutex_);
		cond_.wait(lock, [this] { return !queue_.empty(); });
		T value = std::move(queue_.front());
		queue_.pop();
		return value;
	}

	// Non-blocking try_pop
	bool try_pop(T& value) {
		std::lock_guard<std::mutex> lock(mutex_);
		if (queue_.empty()) return false;
		value = std::move(queue_.front());
		queue_.pop();
		return true;
	}

	bool empty() const {
		std::lock_guard<std::mutex> lock(mutex_);
		return queue_.empty();
	}

private:
	mutable std::mutex mutex_;
	std::queue<T> queue_;
	std::condition_variable cond_;
};

/******************************************************************/
/* FUNCTION PROTOTYPES */
/******************************************************************/

/* Utility functions */
int send_all(SOCKET s, const char* buf, int len);
int recv_all(SOCKET s, char* buf, int len);
int send_message(SOCKET s, uint16_t msg_type, const void* payload, uint16_t payload_len);

/* Main functions */
int OpenClientConnection(SOCKET* ClientSocket);
int SendPosition(SOCKET* ClientSocket, const Position& pos);
//MsgHeader ReceiveCommand(SOCKET* ClientSocket, FalconCommand* cmd_handler);
int SendInfo(SOCKET* ClientSocket, char* sendbuf, int sendlen);
int CloseClientConnection(SOCKET* ClientSocket);

/* Asynchronous API */
//void QueuePositionToSend(const Position& pos);
//bool GetReceivedCommand(FalconCommand& cmd); // Non-blocking

#endif