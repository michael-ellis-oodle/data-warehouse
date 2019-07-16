DROP table dtc;

CREATE table dtc as    

with opportunity_dtc as
         (SELECT o.CreatedDate        as ApplicationCreatedDate,
        o.closed_date__c,
        Main_Applicant_Full_Name__c,
        o.StageName,
        o.Underwriting_Stage_Status__c,
        o.Name               as ApplicationName,
        o.Id                 as SalesforceId,
        Affiliate_ID__c,
        Affiliate_Sub_ID__c,
        Source__c,
        LeadSource,
        Stage_at_Loss__c,
        o.closed_reason__c,
        o.total_finance_amount__c,
        Finance_Term__c,
        Cash_Deposit__c,
        Max_Loan_Amount__c,
        Amount,
        Customer_Requested_Monthly_Amount__c,
        Flat_Rate__c,
        o.apr__c,
        External_Campaign_ID__c,
        Ad_Group_Keywords__c,
        Finance_Terms_Stage_Status__c,
        Payout_Stage_Status__c,
        Offer_Stage_Status__c,
        Proposal_Stage_Status__c,
        Documentation_Stage_Status__c,
        Rating_Status__c,
        Global_Rating__c,
        o.Main_Applicant__c,
        p.createddate        as ProspectCreatedDate,
        p.contact_attempts__c,
        p.dealer_cheque_received__c,
        p.dealer_companies_house_url__c,
        p.dealer_fca_url__c,
        p.dealer_invoice_received__c,
        p.dealer_reviews_url__c,
        p.dealer_signed_terms__c,
        p.dealer_vat_url__c,
        p.last_contacted__c,
        p.last_contacted_by__c,
        p.lastactivitydate,
        p.name               as ProspectName,
        p.status__c,
        p.unique_key__c,
        a.Email__c,
        a.phone__c,
        p.inbound_call_progress_made__c,
        p.inbound_email_progress_made__c,
        p.outbound_call_progress_made__c,
        p.Application_Complete__c,
        p.Bank_details_populated__c,
        p.Contact_Successful__c,
        p.Dealer_Negotiation_Complete__c,
        p.Finance_Criteria_Complete__c,
        p.LastReferencedDate,
        p.LastViewedDate,
        p.Loan_Application_Stage__c,
        p.Offer_Accepted__c,
        p.Onboarding_Complete__c,
        p.Underwriting_Accepted__c,
        p.Vehicle_Details_Complete__c,
       CASE
           WHEN source__c = 'Dealer Portal' THEN 'Dealer Portal'
           WHEN o.name = 0 Then ''
           WHEN o.affiliate_id__c in ('006c1358-17e8-46e8-9cde-446aa3db83c9', 'ocf_carsnip_widget') THEN 'OCF'
           WHEN source__c = 'ODIT' THEN 'ODIT'
           WHEN source__c = 'Carsnip' AND (leadsource = 'CarSnip' or leadsource IS NULL) THEN 'Carsnip'
           WHEN leadsource = 'CarSnip' THEN 'Carsnip'
           WHEN source__c = 'HYPERLOCAL' THEN 'OCF'
           WHEN source__c = 'Carsnip' and leadsource in ('FacebookPaid', 'Bing', 'Google') THEN 'ODIT'
           ELSE 'UNKNOWN'
           END              as calculated_source,
       CAST(CASE
                WHEN amount > 200000 THEN 10000
                WHEN Amount > 0 THEN Amount
                WHEN Customer_Requested_Monthly_Amount__c < 50 THEN 10000
                WHEN Customer_Requested_Monthly_Amount__c > 1000 THEN Customer_Requested_Monthly_Amount__c
                WHEN Flat_Rate__c > 0 THEN ROUND((Finance_Term__c * Customer_Requested_Monthly_Amount__c - 100) /
                                                 (1 + Finance_Term__c * Flat_Rate__c / 1200), 2)
                WHEN Flat_Rate__c IS NULL THEN ROUND((Finance_Term__c * Customer_Requested_Monthly_Amount__c - 100) /
                                                     (1 + Finance_Term__c * 9.5 / 1200), 2)
           END AS FLOAT)    as calculated_amount,
       CASE
           WHEN LeadSource = 'Google' AND Calculated_Source = 'OCF' Then 'Google'
           WHEN LeadSource = 'FacebookPaid' AND Calculated_Source = 'OCF' Then 'Facebook'
           WHEN LeadSource = 'bing' AND Calculated_Source = 'OCF' Then 'Bing'
           WHEN LeadSource isnull AND Calculated_Source = 'OCF' Then 'Direct'
           WHEN affiliate_id__c in ('006c1358-17e8-46e8-9cde-446aa3db83c9', 'ocf_carsnip_widget') THEN 'Widget'
           WHEN calculated_source = 'Carsnip' THEN 'Carsnip'
           WHEN LeadSource = 'Google' AND Calculated_Source = 'ODIT' Then 'Google'
           WHEN LeadSource = 'FacebookPaid' AND Calculated_Source = 'ODIT' Then 'Facebook'
           WHEN LeadSource = 'Bing' AND Calculated_Source = 'ODIT' Then 'Bing'
           WHEN LeadSource isnull AND Calculated_Source = 'ODIT' Then 'Direct'
           ELSE 'other' END as leadsourcereduced
from salesforce_ext.opportunity o
         LEFT JOIN salesforce_ext.applicant__c a
                   ON a.Id = o.Main_Applicant__c
         LEFT JOIN salesforce_ext.prospect__c p
                   ON p.loan_application__c = o.id
WHERE LOWER(Main_Applicant_Full_Name__c) not LIKE '%duck'
  AND LOWER(Main_Applicant_Full_Name__c) not LIKE '%donald duck%'
  AND LOWER(Main_Applicant_Full_Name__c) not LIKE '%mouse%'
  AND LOWER(Main_Applicant_Full_Name__c) not LIKE '%mickey m%'
  AND LOWER(Main_Applicant_Full_Name__c) not LIKE '%dog'
  AND LOWER(Main_Applicant_Full_Name__c) not LIKE '%dawg'
  AND a.Email__c != 'test@test.com'
  AND a.Phone__c != '07787511611'
  AND (o.Introducer_ID__c = '0015800000rFmp1AAC'
    OR Source__c in ('HYPERLOCAL', 'Carsnip', 'ODIT'))
  AND (o.closed_reason__c != 'Test Application' OR o.closed_reason__c IS NULL)),
     
     dealer_portal as

(SELECT DISTINCT LAST_VALUE(non_dp.applicationname)
                      over (PARTITION BY dp.applicationname ORDER BY non_dp.applicationcreateddate asc ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as non_dp_name,
                      dp.applicationname                                                                                                                     as dp_name
      FROM (SELECT applicationname, applicationcreateddate, email__c, main_applicant_full_name__c FROM opportunity_dtc
          WHERE calculated_source = 'Dealer Portal') dp
              LEFT JOIN
           (SELECT applicationname, applicationcreateddate, email__c, main_applicant_full_name__c
            FROM opportunity_dtc
            WHERE calculated_source != 'Dealer Portal') non_dp
           ON (dp.email__c = non_dp.email__c OR dp.main_applicant_full_name__c = non_dp.main_applicant_full_name__c)
               AND dp.applicationcreateddate >= non_dp.applicationcreateddate
            AND dp.applicationcreateddate <= non_dp.applicationcreateddate + interval '30 days')


SELECT o1.StageName,
       o1.applicationname   as applicationname,
       o1.salesforceid,
       o1.Underwriting_Stage_Status__c,
       o1.main_applicant_full_name__c,
       o1.Finance_Term__c,
       o1.Cash_Deposit__c,
       o1.Max_Loan_Amount__c,
       o1.Amount,
       o1.Customer_Requested_Monthly_Amount__c,
       o1.Flat_Rate__c,
       o1.calculated_amount,
       o1.apr__c,
       o1.total_finance_amount__c,
       o1.Finance_Terms_Stage_Status__c,
       o1.Payout_Stage_Status__c,
       o1.Offer_Stage_Status__c,
       o1.Proposal_Stage_Status__c,
       o1.Documentation_Stage_Status__c,
       o1.Rating_Status__c,
       o1.Global_Rating__c,
       o1.Main_Applicant__c,
       o1.Email__c,
       o1.Calculated_Source,
       timestamp 'epoch' + o1.closed_date__c * interval '1 second'/1000 as closed_date__c,
       o2.applicationname   as originalapplicationname,
       o2.Affiliate_ID__c,
       o2.Affiliate_Sub_ID__c,
       timestamp 'epoch' + COALESCE(o2.applicationcreateddate,o1.applicationcreateddate) * interval '1 second'/1000 as applicationcreateddate,
       o2.Source__c,
       o2.leadsource,
       o2.leadsourcereduced,
       o2.External_Campaign_ID__c,
       o2.Ad_Group_Keywords__c,
       o2.inbound_call_progress_made__c,
       o2.inbound_email_progress_made__c,
       o2.outbound_call_progress_made__c,
       o2.Application_Complete__c,
        o2.Bank_details_populated__c,
        o2.Contact_Successful__c,
        o2.Dealer_Negotiation_Complete__c,
        o2.Finance_Criteria_Complete__c,
        o2.LastReferencedDate,
        o2.LastViewedDate,
        o2.Loan_Application_Stage__c,
        o2.Offer_Accepted__c,
        o2.Onboarding_Complete__c,
        o2.Underwriting_Accepted__c,
        o2.Vehicle_Details_Complete__c,
       MAX(CASE WHEN o1.stagename = 'Closed - Funded' THEN 1 ELSE 0 END) over (partition by o1.email__c order by o1.applicationcreateddate asc rows between unbounded PRECEDING and 1 PRECEDING) as existing_customer
FROM
     (SELECT o.applicationname as non_dp_name, o.applicationname as dp_name
    FROM opportunity_dtc o
    LEFT JOIN
          (SELECT dp_name as applicationname
          FROM dealer_portal
        UNION ALL
          SELECT non_dp_name as applicationname
        FROM dealer_portal) t
     ON t.applicationname = o.applicationname
     WHERE t.applicationname IS NULL
    UNION ALL
    SELECT non_dp_name, dp_name
          FROM dealer_portal) t
LEFT JOIN opportunity_dtc o1
              ON t.dp_name = o1.applicationname
LEFT JOIN opportunity_dtc o2
              ON t.non_dp_name = o2.applicationname;





