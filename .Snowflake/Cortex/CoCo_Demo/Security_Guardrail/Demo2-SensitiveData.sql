--Demo 2: PII Masking - CoCo sees masked data only

-- Now grant COCO_RESTRICTED read on CUSTOMERS (masking will apply automatically)
USE ROLE ACCOUNTADMIN;
GRANT SELECT ON TABLE COCO_SECURITY_DEMO.CUSTOMER_DATA.CUSTOMERS TO ROLE COCO_RESTRICTED;

--REVOKE SELECT ON TABLE COCO_SECURITY_DEMO.CUSTOMER_DATA.CUSTOMERS FROM ROLE COCO_RESTRICTED;

-- SHOW GRANTS TO ROLE COCO_RESTRICTED;

-- Switch to the restricted role
USE ROLE COCO_RESTRICTED;
USE SECONDARY ROLES NONE;

Select * FROM COCO_SECURITY_DEMO.CUSTOMER_DATA.CUSTOMERS ;

--prompt
Give me the full details for customer ID 1001 including their email and social security number.

How many customers signed up in 2022, and which countries are they from?



