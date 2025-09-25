component extends="farcry.core.packages.types.types" displayName="API Logging" {

    property name="id" type="identity" required="true" default="0"
             ftSeq="1" ftFieldset="Logging" ftLabel="ID" ftDisplayOnly="true";

	property name="req" type="json" required="false"
			 ftSeq="2" ftFieldSet="Logging" ftLabel="Request";

    property name="res" type="json" required="false"
			 ftSeq="3" ftFieldSet="Logging" ftLabel="Request";

    property name="event" type="string" required="false"
			 ftSeq="4" ftFieldSet="Logging" ftLabel="Event";

    property name="requestId" type="string" required="false"
			 ftSeq="5" ftFieldSet="Logging" ftLabel="Request ID";

}