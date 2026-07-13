1. 如果只是小專題、文章標籤只拿來顯示或簡單篩選，JSONB 可以繼續用，Spring Boot 用 nativeQuery 查。
如果這是要長期維護的後端，或之後會有後台新增標籤、標籤篩選、熱門標籤統計、標籤改名，就拆成 tags + article_tags，比較符合 Spring Boot/JPA 的使用方式。

2. 討論完全部的md 在整合一次確認spring boot 和sql 各自要負責的架構要確認清楚。
3. 確認spring boot 和現在的整合方式有所衝突

