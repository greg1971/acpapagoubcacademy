procedure dip_rml_attr_assoc (num integer) is
    begin
      log_update(num, 'RML attr start');


      -- create attributes
      log_update(num, 'RML attr start loading DIP_RML_PROCESS_ATTRIBUTE');
      INSERT INTO DIP_RML_PROCESS_ATTRIBUTE (
          RML_ID, IDENTITY_ATTRIBUTE_TYPE, IDENTITY_ATTRIBUTE_VALUE, PROCESS_NAME, SUB_PROCESS_NAME,REGULATION_NAME, DATE_MODIFIED, ATTRIBUTE_STATUS, S_CREATED_DATE, S_MODIFIED_DATE
      )
          with pic as (
            -- AzDO-661537: Special handling of PIC attributes
           select RML_ID, IDENTITY_ATTRIBUTE_TYPE,
                  IDENTITY_ATTRIBUTE_VALUE,
                  a.REGULATION_NAME as PROCESS_NAME,
                  A.PROCESS_NAME as SUB_PROCESS_NAME,
                  a.REGULATION_NAME, DATE_MODIFIED, ATTRIBUTE_STATUS
             from
                  DIP_ST_RML_ATTR_ASSOC_DISS A
           where REGULATION_NAME='PIC'
             and PROCESS_NAME !='PIC_INVENTORY'
             and UPPER(ATTRIBUTE_STATUS) IN ('PREFERRED','ACTIVE')
             and RML_ID IN (SELECT RML_ID FROM DIP_RML_SUBSTANCE)
          ), other as (
            -- AzDO-661537: General handling of non PIC attributes
           select RML_ID, IDENTITY_ATTRIBUTE_TYPE,
                  IDENTITY_ATTRIBUTE_VALUE,
                  nvl(d.DISS_PROCESS_NAME, CASE WHEN e.EUC_LEG_LIST_ID IS NULL THEN 'OTHER' ELSE 'EUCLEF' END ) PROCESS_NAME,
                  COALESCE(e.EUC_LEG_LIST_ID,d.DISS_PROCESS_NAME, 'OTHER') SUB_PROCESS_NAME,
                  REGULATION_NAME, DATE_MODIFIED, ATTRIBUTE_STATUS
             from
                  DIP_ST_RML_ATTR_ASSOC_DISS A
             left join
                  DIP_PROCESS_NAME_DISS d on d.DIP_PROCESS_NAME = A.PROCESS_NAME
             left join
                  EUC_DOM_LEG_LISTS e on e.EUC_LEG_LIST_ID = A.PROCESS_NAME AND e.EDB_STATUS='L'
           where (REGULATION_NAME!='PIC' or (REGULATION_NAME='PIC' and PROCESS_NAME='PIC_INVENTORY'))
             and UPPER(ATTRIBUTE_STATUS) IN ('PREFERRED','ACTIVE')
             and RML_ID IN (SELECT RML_ID FROM DIP_RML_SUBSTANCE)
          ), combined as (
            select a.* from pic a
            union all
            select b.* from other b
          ),d as (
           select c.*, SYSDATE S_CREATED_DATE, SYSDATE S_MODIFIED_DATE, rownum rn
           from combined c
          ), unique_other as (
              select d.*,
                     first_value (rn) over (partition by RML_ID, IDENTITY_ATTRIBUTE_TYPE, IDENTITY_ATTRIBUTE_VALUE, PROCESS_NAME, SUB_PROCESS_NAME
                                            order by case when ATTRIBUTE_STATUS = 'ACTIVE' then 1 else 0 end desc, DATE_MODIFIED desc) fv
                from d
          )
          select RML_ID, IDENTITY_ATTRIBUTE_TYPE, IDENTITY_ATTRIBUTE_VALUE, PROCESS_NAME, SUB_PROCESS_NAME,
                 REGULATION_NAME, DATE_MODIFIED, ATTRIBUTE_STATUS, S_CREATED_DATE, S_MODIFIED_DATE
            from unique_other where rn = fv;
      log_update(num, 'RML attr end loading DIP_RML_PROCESS_ATTRIBUTE');


      log_update(num, 'RML attr start loading RML_PROCESS_ATTRIBUTE');
      INSERT INTO RML_PROCESS_ATTRIBUTE (
          RML_ID, IDENTITY_ATTRIBUTE_TYPE, IDENTITY_ATTRIBUTE_VALUE, PROCESS_NAME, SUB_PROCESS_NAME, REGULATION_NAME, DATE_MODIFIED, ATTRIBUTE_STATUS
          )
      SELECT
             RML_ID, IDENTITY_ATTRIBUTE_TYPE, IDENTITY_ATTRIBUTE_VALUE, PROCESS_NAME, SUB_PROCESS_NAME, REGULATION_NAME, DATE_MODIFIED, ATTRIBUTE_STATUS
      FROM DIP_RML_PROCESS_ATTRIBUTE;
      log_update(num, 'RML attr end loading RML_PROCESS_ATTRIBUTE');


      log_update(num, 'RML attr done');
    end;