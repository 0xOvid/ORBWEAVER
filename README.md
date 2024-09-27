# ORBWEAVER
This is a combination of agent and server. The purpose of these is to be able to "remote control" a host. This is intended to be a proxy for RDP so that an active users session can be stolen to access otherwise unaccessable resources. The reason for choosing this approach is versatility and simplicity. Yes, you could steal the various tokens from browsers and applications - this would be more stealthy. But good luck reversing these on an app by app basis. 

## Purpose
Provide the capability to spy on user sessions and control their actions without the need for third party applications.

# TODO
- create install instructions
- create compile instructions
- finsih github setup
- create blog post
- do field testing
- create demo of final PoC
- release and scrub github history
## Agent
- Provide commandline options for where to connect to
- Clean up code base
- Add option to use authentication token

## Server
- Add security: checking fo files that are uploaded, login, and auth requirements for interfaces and APIs
- Add CSS
- Clean up web interface
- Add functionality to keep track of agent: last call back time, color to indicate status, hsotname, username, maybe process info (see sidewinder)


