// SPDX-License-Identifier: Apache-2.0
import com.ericsson.otp.erlang.OtpErlangAtom;
import com.ericsson.otp.erlang.OtpErlangLong;
import com.ericsson.otp.erlang.OtpErlangObject;
import com.ericsson.otp.erlang.OtpErlangTuple;
import com.ericsson.otp.erlang.OtpInputStream;
import com.ericsson.otp.erlang.OtpOutputStream;

public final class JinterfaceSmoke {
    public static void main(String[] args) throws Exception {
        OtpErlangTuple value = new OtpErlangTuple(new OtpErlangObject[] {
            new OtpErlangAtom("installed"), new OtpErlangLong(42)
        });
        OtpOutputStream encoded = new OtpOutputStream(value);
        OtpErlangObject decoded = new OtpInputStream(encoded.toByteArray()).read_any();
        if (!value.equals(decoded)) {
            throw new AssertionError("installed Jinterface ETF roundtrip differs");
        }
        System.out.println("otp-jinterface-ok");
    }
}
