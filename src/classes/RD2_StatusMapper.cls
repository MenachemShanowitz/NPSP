/*
    Copyright (c) 2020 Salesforce.org
    All rights reserved.
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2020
* @group Recurring Donations
* @description Enhanced Recurring Donation Status Mapping Setting
*
*/
public with sharing class RD2_StatusMapper {

    /**
    * @description Status To State Mapping instance
    */
    @TestVisible
    private static RD2_StatusMapper statusMapper;

    /**
    * @description Returns Status To State Mapping instance
    * @return RD2_StatusMapper Status To State Mapping
    */
    public static RD2_StatusMapper getInstance() {
        if (statusMapper == null) {
            statusMapper = new RD2_StatusMapper();
        }
        return statusMapper;
    }

    /**
    * @description Get the mapped State from the Status
    * @param status Recurring Donation Status
    * @return String 
    */
    public String getState(String status) {
        if (status == RD2_Constants.STATUS_ACTIVE) {
            return RD2_Constants.STATUS_ACTIVE;

        } else if (status == RD2_Constants.STATUS_LAPSED) {
            return RD2_Constants.STATUS_LAPSED;

        } else if (status == RD2_Constants.STATUS_CLOSED) {
            return RD2_Constants.STATUS_CLOSED;
        }

        return null;
    }
}