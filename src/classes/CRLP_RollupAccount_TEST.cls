/*
    Copyright (c) 2018, Salesforce.org
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
* @date 2018
* @group Customizable Rollups Operations Services
* @description Unit Test for the Opportunity/Payment to Account Rollups (Hard Credit Only)
*/
@IsTest
public class CRLP_RollupAccount_TEST {

    /** @description The 6 testing types supported by the test engine */
    private Enum TestType {
        TestTrigger, TestQueueuable, TestBatch, TestSkewBatch, TestMultiCurrBatch, TestReparentOpp
    }

    /**
     * @description Test Setup: Insert a dummy contact and let it create an Account. The Opportunity data has to
     * be created in the actual unit test to allow for the trigger test to run
     */
    @TestSetup
    private static void setupBaseTestData() {
        Contact c = UTIL_UnitTestData_TEST.getContact();
        insert c;
        Account acc = UTIL_UnitTestData_TEST.buildHouseholdAccount();
        insert acc;
    }

    /**
     * @description Create Rollup__mdt records to test rolling up from the Opp and Payment objects to the Account
     */
    public static void mockRollupCMTValues() {

        String donationRTId = UTIL_RecordTypes.getRecordTypeIdForGiftsTests(Opportunity.SObjectType);
        String membershipRTId = UTIL_RecordTypes.getRecordTypeIdForMembershipTests(Opportunity.SObjectType);
        RecordType rtDonation = [SELECT DeveloperName FROM RecordType WHERE Id = :donationRTId LIMIT 1];
        RecordType rtMembership = [SELECT DeveloperName FROM RecordType WHERE Id = :membershipRTId LIMIT 1];

        // Create a single Filter Group (no need for filter rules here)
        String filterGroupId1 = CMT_UnitTestData_TEST.getNewRecordId();
        String filterGroupId2 = CMT_UnitTestData_TEST.getNewRecordId();
        String filterGroupId3 = CMT_UnitTestData_TEST.getNewRecordId();

        DateTime dt = DateTime.now().addMonths(-100).addDays(-1);
        String dtValue = dt.format('yyyy-MM-dd', UserInfo.getTimezone().toString());

        // Simple testing filters for IsWon, RecordType, and Paid/Written Off
        String filterGroupsJSON = '[' +
            CMT_UnitTestData_TEST.createFilterGroupRecord(filterGroupId1, 'TestFilterGroup1-IsWon+Paid') + ',' +
            CMT_UnitTestData_TEST.createFilterGroupRecord(filterGroupId2, 'TestFilterGroup2-IsWon+WrittenOff') + ',' +
            CMT_UnitTestData_TEST.createFilterGroupRecord(filterGroupId3, 'TestFilterGroup3-IsLost') +
        ']';

        String filterRulesJSON = '[' +
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId1, 'Group1.Rule1', 'Opportunity', 'IsWon', 'Equals', 'True') + ',' +
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId1, 'Group1.Rule2', 'Opportunity', 'RecordTypeId', 'Equals', rtDonation.DeveloperName) + ',' +
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId1, 'Group1.Rule3', 'npe01__OppPayment__c', 'npe01__Paid__c', 'Equals', 'True') + ',' +
            /* Add a rule that should filter out Opportunities created more than 100 months ago */
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId1, 'Group1.Rule4', 'Opportunity', 'CloseDate', CMT_FilterRule.FilterOperation.Greater.name(), dtvalue) + ',' +

            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId2, 'Group2.Rule1', 'Opportunity', 'IsWon', 'Equals', 'True') + ',' +
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId2, 'Group2.Rule2', 'Opportunity', 'RecordTypeId', 'Equals', rtDonation.DeveloperName) + ',' +
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId2, 'Group2.Rule3', 'npe01__OppPayment__c', 'npe01__Written_Off__c', 'Equals', 'True') + ',' +

            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId3, 'Group3.Rule1', 'Opportunity', 'IsWon', 'Equals', 'False') + ',' +
            CMT_UnitTestData_TEST.createFilterRuleRecord(null, filterGroupId3, 'Group3.Rule2', 'Opportunity', 'IsClosed', 'Equals', 'True') +
        ']';

        // Deserialize the filter group and filter rule to use for the tests
        CMT_FilterRule_SEL.cachedFilterGroups = (List<Filter_Group__mdt>)JSON.deserialize(filterGroupsJSON, List<Filter_Group__mdt>.class);
        CMT_FilterRule_SEL.cachedFilterRules = (List<Filter_Rule__mdt>)JSON.deserialize(filterRulesJSON, List<Filter_Rule__mdt>.class);

        // Create a single Rollup that uses the above Filter Group
        // TODO Add many more rollup variations to this
        String rollupsJSON = '[' +
                CMT_UnitTestData_TEST.createRollupRecord('Household Total Donations All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__TotalOppAmount__c', CRLP_Operation.RollupType.SUM, 'Amount') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Average Total Donations All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__AverageAmount__c', CRLP_Operation.RollupType.AVERAGE, 'Amount') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Household Total Donations Last 2 Years', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__OppAmount2YearsAgo__c', CRLP_Operation.RollupType.SUM, 'Amount',
                        CRLP_Operation.TimeBoundOperationType.YEARS_AGO, 2) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Total Donations Last 365 Days', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__OppAmountLastNDays__c', CRLP_Operation.RollupType.SUM, 'Amount',
                        CRLP_Operation.TimeBoundOperationType.DAYS_BACK, 365) + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Largest Donation All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__LargestAmount__c', CRLP_Operation.RollupType.LARGEST, 'Amount') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Test Field Truncation', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        //Sic is a standard field of type Text(20), allowing us to verify text field truncation
                        'Sic', CRLP_Operation.RollupType.LARGEST, 'Name', 'Amount') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Smallest Donation All Time', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__SmallestAmount__c', CRLP_Operation.RollupType.Smallest, 'Amount') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Years Donated', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'Description', CRLP_Operation.RollupType.YEARS_DONATED, '') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Current Donation Streak', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__NumberOfMembershipOpps__c', CRLP_Operation.RollupType.Donor_Streak, '') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Best Year', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__Best_Gift_Year__c', CRLP_Operation.RollupType.BEST_YEAR, '') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Last Gift Date', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__LastCloseDate__c', CRLP_Operation.RollupType.LAST, 'CloseDate') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('First Gift Date', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__FirstCloseDate__c', CRLP_Operation.RollupType.First, 'CloseDate') + ',' +

                // Allow counting of all Opportunities regardless of the filter. This should have a different
                // result than the normal expected count. It is meant to validate proper grouping of rollups.
                CMT_UnitTestData_TEST.createRollupRecord('Total Count with NO filter', null,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__OppAmountThisYear__c', CRLP_Operation.RollupType.Count, '') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Total Count of Opps', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__OppAmountLastYear__c', CRLP_Operation.RollupType.Count, '') + ',' +

                /* Using a simple Count to validate YearsAgo operations with a different Filter Group.
                *  Purposely only use one rollup with this filter group to test rollup grouping logic */
                CMT_UnitTestData_TEST.createRollupRecord('Count Test with Different Filter', filterGroupId3,
                        CMT_UnitTestData_TEST.RollupRecordType.OppToAcct,
                        'npo02__OppsClosed2YearsAgo__c', CRLP_Operation.RollupType.Count, null,
                        CRLP_Operation.TimeBoundOperationType.YEARS_AGO, 0) + ',' +

                /* Payment Rollups for Total Paid and Total Written Off - using a field that can hold the value */
                CMT_UnitTestData_TEST.createRollupRecord('Total Payments', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.PmtToAcct,
                        'AnnualRevenue', CRLP_Operation.RollupType.SUM, 'npe01__Payment_Amount__c') + ',' +

                CMT_UnitTestData_TEST.createRollupRecord('Total Writeoffs', filterGroupId2,
                        CMT_UnitTestData_TEST.RollupRecordType.PmtToAcct,
                        'npo02__LastMembershipAmount__c', CRLP_Operation.RollupType.SUM, 'npe01__Payment_Amount__c') + ',' +

                // Using a nonsense field for an Account Soft Credit test since we don't package anything for Account Soft Credits
                CMT_UnitTestData_TEST.createRollupRecord('Total Account Soft Credits', filterGroupId1,
                        CMT_UnitTestData_TEST.RollupRecordType.AccountSoftCreditToAccount, 'npo02__Best_Gift_Year_Total__c',
                        CRLP_Operation.RollupType.SUM, 'Amount__c') +

                ']';

        // Deserialize the rollups to use for testing
        CRLP_Rollup_SEL.cachedRollups = (List<Rollup__mdt>) JSON.deserialize(rollupsJSON, List<Rollup__mdt>.class);
    }

    /** @description Test the asynchronous queuable method of rolling up */
    static testMethod void test_Rollups_Queueable() {
        testRollupsServices(TestType.TestQueueuable);
    }
    /** @description Test the full non-skew batch job method of rolling up */
    static testMethod void test_Rollups_Batch() {
        testRollupsServices(TestType.TestBatch);
    }
    /** @description Test the full skew mode batch job method of rolling up */
    static testMethod void test_Rollups_SkewBatch() {
        testRollupsServices(TestType.TestSkewBatch);
    }
    /** @description Test the Trigger method of rolling up */
    static testMethod void test_Rollups_Trigger() {
        testRollupsServices(TestType.TestTrigger);
    }
    /** @description Test the Trigger method of rolling up when reparenting an Opp to a different Account */
    static testMethod void test_Rollups_ReparentOppAccount() {
        testRollupsServices(TestType.TestReparentOpp);
    }

    /* @description Default currency for the current user (if MC is enabled in the Org) */
    private static String defaultCurrCode = UserInfo.getDefaultCurrency();
    /* @description A different currency code to use for the MultiCurrency batch test */
    private static String otherCurrencyCode;

    /**
     * @description Tests a specific scenario in a MultiCurrency Enabled Org (with at least 2 currencies)
     * where the batch job was not properly setting the currency code for each target record. This test can only
     * run in a Multicurrency enabled org to allow the currency code values to be set on the Account and related Opp.
     */
    static testMethod void test_Rollups_MultiCurrencyBatch() {

        // Test is only relevant for multi-currency organizations.  If not, skip it
        if (!UserInfo.isMultiCurrencyOrganization()) {
            return;
        }

        UtilCurrencyCacheMock mockCurrencyCache = new UtilCurrencyCacheMock();
        UTIL_CurrencyCache.instance = mockCurrencyCache;

        // Define a simple 2x exchange rate to use for this test
        mockCurrencyCache.effectiveRatesReturn = new List<Decimal>{ 2.0 };
        mockCurrencyCache.effectiveDatesReturn = new List<Date>{ Date.newInstance(1900,1,1) };

        // Test is only relevant if the multicurrency org actually has multiple currencies.   If not, skip it
        SObject[] currencies = Database.query('SELECT IsoCode FROM CurrencyType WHERE IsActive = True');
        if (currencies.size() <= 1) {
            return;
        }

        // Get another currency code to use for the future tests
        for (SObject curr : currencies) {
            if ((String)curr.get('IsoCode') != defaultCurrCode) {
                otherCurrencyCode = (String)curr.get('IsoCode');
                break;
            }
        }

        // Enable for standard currency management in the mock
        UTIL_Currency_TEST.UtilCurrencyMock mockCurr = new UTIL_Currency_TEST.UtilCurrencyMock();
        UTIL_Currency.instance = mockCurr;
        mockCurr.orgDefaultCurrencyReturn = defaultCurrCode;
        mockCurr.getDefaultCurrencyReturn = defaultCurrCode;
        mockCurr.isAdvancedCurrencyManagementEnabledReturn = false; // we're forcing the rates rather than attempting to query
        mockCurr.isMultiCurrencyOrganizationReturn = true;

        // Execute the rollup service test
        testRollupsServices(TestType.TestMultiCurrBatch);
    }

    /**
     * @description Test some simple rollups from the Opportunity/Payment object to the Account using
     * four different methods:
     * 1. Trigger based rollup
     * 2. Call a Queueuable method directly (simulates clicking a button to recalculate)
     * 3. Nightly Batch Job
     * 4. Nightly LDV Batch Job
     */
    private static void testRollupsServices(TestType tt) {

        // Start by enabling Customizable Rollups (which disables all legacy rollup operations)
        UTIL_CustomSettingsFacade.getRollupSettingsForTests(new Customizable_Rollup_Settings__c (
                Customizable_Rollups_Enabled__c = true,
                Rollups_Limit_on_Attached_Opps_for_Skew__c = (tt == TestType.TestSkewBatch ? 50 : 200),
                Rollups_Account_SkewMode_Batch_Size__c = 200,
                Rollups_Contact_SkewMode_Batch_Size__c = 200,
                Rollups_Contact_Soft_Credit_Batch_Size__c = 200,
                Rollups_Account_Batch_Size__c = 20,
                Rollups_Contact_Batch_Size__c = 20
        ));
        UTIL_CustomSettingsFacade.getContactsSettingsForTests(new npe01__Contacts_And_Orgs_Settings__c(
                npe01__Opportunity_Contact_Role_Default_role__c = CAO_Constants.OCR_DONOR_ROLE,
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                npe01__Payments_Enabled__c = true
        ));

        UTIL_CustomSettingsFacade.getHouseholdsSettingsForTests(new npo02__Households_Settings__c (
                npo02__Household_Rules__c = HH_Households.ALL_PROCESSOR,
                npo02__Household_Member_Contact_Role__c = CAO_Constants.HH_MEMBER_CONTACT_ROLE,
                npo02__Household_Contact_Roles_On__c = true,
                npo02__Always_Rollup_to_Primary_Contact__c = false
        ));

        // Create the test data
        mockRollupCMTValues();

        // Disable all legacy rollup triggers
        UTIL_UnitTestData_TEST.disableRollupTriggers();

        if (tt != TestType.TestTrigger && tt != TestType.TestReparentOpp) {
            // disable customizable rollup triggers to test the Batch & Queueuable logic
            UTIL_UnitTestData_TEST.disableCustomizableRollupTriggers();
        }

        // Retrieve the dummy Contact and then insert 100 Opportunity records
        Contact c = [SELECT Id, FirstName, LastName, AccountId FROM Contact LIMIT 1];
        Id hardCreditAccId = c.AccountId;

        String closedStage = UTIL_UnitTestData_TEST.getClosedWonStage();
        Id rtId = UTIL_RecordTypes.getRecordTypeIdForGiftsTests(Opportunity.SObjectType);

        List<Opportunity> opps = new List<Opportunity>();
        final Date closeDate = Date.Today().addMonths(-100);
        final Decimal maxAmt = 1000;
        final Decimal baseAmt = 100;
        final Integer cnt = 100;
        Decimal totalDonations = 0, total2YearsAgo = 0;
        String bestGiftYear;
        Set<String> donationYears = new Set<String>();
        Date lastCloseDate;
        for (Integer n=0; n<cnt; n++) {
            Decimal amt = (n==50 ? maxAmt : baseAmt);
            opps.add(new Opportunity (
                    Name = 'Test Opp ' + c.FirstName + ' ' + c.LastName + '-' + n,
                    Amount = amt,
                    CloseDate = closeDate.addMonths(n),
                    StageName = closedStage,
                    Primary_Contact__c = c.Id,
                    RecordTypeId = rtId
            ));
            totalDonations += amt;
            if (closeDate.addMonths(n).year() == Date.Today().addYears(-2).year()) {
                total2YearsAgo += amt;
            }
            String donationYr = UTIL_String.removeNonNumericCharacters(closeDate.addMonths(n).year().format());
            donationYears.add(donationYr);
            if (amt == maxAmt) {
                bestGiftYear = donationYr;
            }
            lastCloseDate = closeDate.addMonths(n);
        }
        Integer hardCreditAcctOppCount = opps.size();

        // In a multi-currency org, create one Opportunity in the default (probably USD), but set the target Account
        // to a different currency so that the Opp amount will be converted. The mocking of the UTIL_CurrencyCache
        // is handled the the test_Rollups_MultiCurrencyBatch() method above.
        if (tt == TestType.TestMultiCurrBatch) {
            Account multiCurrAcct = [SELECT Id FROM Account WHERE Id != :hardCreditAccId LIMIT 1];
            multiCurrAcct.put('CurrencyIsoCode', otherCurrencyCode);
            Database.update(multiCurrAcct);
            Opportunity opp = new Opportunity(
                Name = 'Test MultiCurrencyOpp',
                Amount = 1000,
                CloseDate = Date.today().addDays(-30),
                StageName = closedStage,
                AccountId = multiCurrAcct.Id,
                RecordTypeId = rtId
            );
            opp.put('CurrencyIsoCode', defaultCurrCode);
            opps.add(opp);
        }

        // create one closed opportunity to ensure it's not included in our rollups
        opps.add(new Opportunity (
                Name = 'Test ClosedWon Opp ' + c.FirstName + ' ' + c.LastName,
                Amount = 500,
                CloseDate = Date.Today().addDays(1),
                StageName = UTIL_UnitTestData_TEST.getClosedLostStage(),
                Primary_Contact__c = c.Id,
                RecordTypeId = rtId
        ));
        hardCreditAcctOppCount++;

        // create one closed won opportunity from BEFORE the earliest date to ensure it's not included
        Date oldCloseDate = closeDate.addDays(-1);
        opps.add(new Opportunity (
                Name = 'Test Not Include' + c.FirstName + ' ' + c.LastName,
                Amount = 50000,
                CloseDate = oldCloseDate,
                StageName = closedStage,
                Primary_Contact__c = c.Id,
                RecordTypeId = rtId,
                npe01__Do_Not_Automatically_Create_Payment__c = true
        ));
        hardCreditAcctOppCount++;

        insert opps;

        npe01__OppPayment__c pmt1 = [SELECT npe01__Written_Off__c, npe01__Paid__c FROM npe01__OppPayment__c
                                        WHERE npe01__Opportunity__r.IsWon = false
                                    LIMIT 1];
        pmt1.npe01__Written_Off__c = true;
        pmt1.npe01__Paid__c = false;    // technically this does not cause a DML change!?

        npe01__OppPayment__c pmt2 = [SELECT npe01__Written_Off__c, npe01__Paid__c FROM npe01__OppPayment__c
                                        WHERE npe01__Opportunity__r.IsWon = true
                                        AND npe01__Written_Off__c = false AND Id != :pmt1.Id
                                    LIMIT 1];
        pmt2.npe01__Written_Off__c = true;
        pmt2.npe01__Paid__c = false;

        Test.startTest();

        // Because data is being modified by the above, any cached filter evaluations are now invalid
        // so before issuing the DML against the payment records, clear any cached eval results
        CMT_FilterRuleEvaluation_SVC.cachedFilterEvalResults.clear();
        update new List<npe01__OppPayment__c>{ pmt1, pmt2 };

        System.assertEquals(cnt, [SELECT Count() FROM npe01__OppPayment__c WHERE npe01__Opportunity__r.IsWon = true
                                AND npe01__Opportunity__r.AccountId = :hardCreditAccId],
                'There should be 100 payment records on closed won opps');
        System.assertEquals(1, [SELECT Count() FROM npe01__OppPayment__c WHERE npe01__Written_Off__c = true
                                AND npe01__Paid__c = false AND npe01__Opportunity__r.IsWon = true
                                AND npe01__Opportunity__r.AccountId = :hardCreditAccId],
                'There should be 1 written off payment record on a closed won opp');
        System.assertEquals(10800, ([SELECT Sum(npe01__Payment_Amount__c) Amt FROM npe01__OppPayment__c
                                WHERE npe01__Paid__c = true AND npe01__Opportunity__r.IsWon = true
                                AND npe01__Opportunity__r.AccountId = :hardCreditAccId])[0].get('Amt'),
                'The total Amount of all Paid Payments should be $10800');

        String baseAccountQuery = CRLP_Query_SEL.buildObjectQueryForRollup(Account.SObjectType);

        String hardCreditAccQuery = baseAccountQuery + ' WHERE Id = :hardCreditAccId LIMIT 1';
        Account hardCreditAcc = Database.query(hardCreditAccQuery);

        // Make sure everything is null first!
        if (tt != TestType.TestTrigger && tt != TestType.TestReparentOpp) {
            System.assertEquals(0, hardCreditAcc.npo02__OppAmountThisYear__c);
            System.assertEquals(0, hardCreditAcc.npo02__OppAmountLastYear__c);
            System.assertEquals(0, hardCreditAcc.npo02__TotalOppAmount__c);
            System.assertEquals(0, hardCreditAcc.npo02__AverageAmount__c);
            System.assertEquals(0, hardCreditAcc.npo02__OppAmount2YearsAgo__c);
            System.assertEquals(0, hardCreditAcc.npo02__LargestAmount__c);
            System.assertEquals(0, hardCreditAcc.npo02__SmallestAmount__c);
            System.assertEquals(null, hardCreditAcc.npo02__LastCloseDate__c);
            System.assertEquals(null, hardCreditAcc.npo02__FirstCloseDate__c);
            System.assertEquals(null, hardCreditAcc.npo02__Best_Gift_Year__c);
            System.assertEquals(null, hardCreditAcc.Sic);
        }

        // Now test the rollups to the Account from the Opportunity
        if (tt == TestType.TestTrigger || tt == TestType.TestReparentOpp) {
            // No need to execute anything special here. If the triggers worked as expected, then
            // the data will be rolled up automatically upon the stopTest().
        } else if (tt == TestType.TestBatch || tt == TestType.TestMultiCurrBatch) {
            CRLP_RollupBatch_SVC.executeBatchRollupJob(CRLP_RollupProcessingOptions.RollupType.AccountHardCredit,
                    CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode, null, null);

        } else if (tt == TestType.TestSkewBatch) {
            CRLP_RollupBatch_SVC.executeBatchRollupJob(CRLP_RollupProcessingOptions.RollupType.AccountHardCredit,
                    CRLP_RollupProcessingOptions.BatchJobMode.SkewMode, new List<Id>{
                            hardCreditAccId
                    }, null);

        } else if (tt == TestType.TestQueueuable) {
            System.enqueueJob(new CRLP_RollupQueueable(new List<Id>{
                    hardCreditAccId
            }));

        }
        Test.stopTest();

        // Query the Accounts with all the target fields specified in the rollups
        hardCreditAcc = Database.query(hardCreditAccQuery);

        // Basic rollup asserts using existing NPSP rollup fields.
        System.assertEquals(totalDonations, hardCreditAcc.npo02__TotalOppAmount__c);
        System.assertEquals(totalDonations.divide(cnt, 2, System.RoundingMode.HALF_UP), hardCreditAcc.npo02__AverageAmount__c);
        System.assertEquals(total2YearsAgo, hardCreditAcc.npo02__OppAmount2YearsAgo__c);
        System.assertEquals(lastCloseDate, hardCreditAcc.npo02__LastCloseDate__c);
        System.assertEquals(closeDate, hardCreditAcc.npo02__FirstCloseDate__c);
        System.assertEquals(maxAmt, hardCreditAcc.npo02__LargestAmount__c);
        System.assertEquals(baseAmt, hardCreditAcc.npo02__SmallestAmount__c);
        System.assertEquals(bestGiftYear, hardCreditAcc.npo02__Best_Gift_Year__c);
        System.assert(hardCreditAcc.Sic.endsWith('...'),
                'Target text field that cannnot contain full rollup contents should truncate.');
        // These 4 use other fields on the Account object since there are no NPSP related fields to store the values in
        System.assertEquals(totalDonations - baseAmt, hardCreditAcc.AnnualRevenue,
                'Total Payments should match total donations less $100 because one payment has been marked as written off');
        System.assertEquals(baseAmt, hardCreditAcc.npo02__LastMembershipAmount__c, 'The Amount written off does not match');
        System.assertEquals(donationYears.size(), hardCreditAcc.npo02__NumberOfMembershipOpps__c, 'The current streak should be all the years');
        System.assertEquals(donationYears.size(), hardCreditAcc.Description.split(';').size(), 'The list of donated years should match');

        System.assertEquals(cnt, hardCreditAcc.npo02__OppAmountLastYear__c, 'Count should be all Won Opps');
        System.assertEquals(hardCreditAcctOppCount, hardCreditAcc.npo02__OppAmountThisYear__c, 'Count should be ALL opps regardless of stage');

        System.assertEquals(1, hardCreditAcc.npo02__OppsClosed2YearsAgo__c, 'The number of close lost opps should be 1');

        if (tt == TestType.TestMultiCurrBatch) {
            // Query the MultiCurrency Account with all the target fields specified in the rollups
            // Only need to validate one of the currency fields to ensure it has been converted correctly.
            Account mcAccount = Database.query(baseAccountQuery + ' WHERE Id != :hardCreditAccId LIMIT 1');
            System.assertEquals(2000, mcAccount.npo02__TotalOppAmount__c);
        }

        if (tt == TestType.TestReparentOpp) {
            // Get the "other" household account to reparent all the opportunities to it
            Id otherAcctId = [SELECT Id FROM Account WHERE Id != :hardCreditAccId].Id;
            for (Opportunity opp : opps) {
                opp.AccountId = otherAcctId;
            }
            Database.update(opps);

            // Query the old and new Accounts
            String otherAccountQuery = baseAccountQuery + ' WHERE Id = :otherAcctId LIMIT 1';
            Account otherAccount = Database.query(otherAccountQuery);
            hardCreditAcc = Database.query(hardCreditAccQuery);

            // Verify that the rollups have run and updated both Accounts.
            System.assertEquals(0, hardCreditAcc.npo02__TotalOppAmount__c, 'The original Account should have its rollups at zero');
            System.assertEquals(totalDonations, otherAccount.npo02__TotalOppAmount__c, 'The new parent Account should now have a rollup');
        }
    }

    /**
     * @description A mock implementation of UTIL_CurrencyCache.Interface_x that can
     * be used to provide pre-set return values from methods and store
     * parameters passed to methods.
     */
    public class UtilCurrencyCacheMock implements UTIL_CurrencyCache.Interface_x {
        public List<Date> effectiveDatesReturn;     // List of dates in Descending date order
        public List<Decimal> effectiveRatesReturn;  // List of rates matching to above dates
        public Decimal defaultRate;                 // Default exchange rate for this currency when not using dated rates

        public Boolean isOrgCacheAvailable() {
            return false;
        }

        public void resetCurrencyCache() { }

        public Map<String, UTIL_CurrencyCache.CurrencyData> getRateMapForCurrencies(List<String> currCodes) {
            Map<String, UTIL_CurrencyCache.CurrencyData> mapOfCurrencyDataByCurrencyCode
                    = new Map<String, UTIL_CurrencyCache.CurrencyData>();

            UTIL_CurrencyCache.CurrencyData currData = new UTIL_CurrencyCache.CurrencyData();
            currData.effectiveDates = effectiveDatesReturn;
            currData.rates = effectiveRatesReturn;
            currData.defaultRate = defaultRate;

            mapOfCurrencyDataByCurrencyCode.put(currCodes[0], currData);
            return mapOfCurrencyDataByCurrencyCode;
        }
        public Integer getCurrDecimalPlaces(String currCode) {
            return 2;
        }

    }
}