#include "quickjs/quickjs.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>

#if defined(JS_NAN_BOXING64)
typedef char jsvalue_nan_boxing64_must_be_8_bytes[(sizeof(JSValue) == 8) ? 1 : -1];
#elif defined(__ANDROID__) && INTPTR_MAX >= INT64_MAX
typedef char jsvalue_android64_must_use_full_pointer_layout[(sizeof(JSValue) == 16) ? 1 : -1];
#endif

static uint64_t double_bits(double value) {
    union {
        double d;
        uint64_t u64;
    } u;
    u.d = value;
    return u.u64;
}

#define CHECK(condition)                                                                                                \
    do {                                                                                                               \
        if (!(condition))                                                                                              \
            abort();                                                                                                   \
    } while (0)

int main(void) {
    JSContext* ctx = NULL;

    JSValue int_value = JS_NewInt32(ctx, -1234567);
    CHECK(JS_VALUE_GET_TAG(int_value) == JS_TAG_INT);
    CHECK(JS_VALUE_GET_NORM_TAG(int_value) == JS_TAG_INT);
    CHECK(JS_VALUE_GET_INT(int_value) == -1234567);

    JSValue bool_value = JS_NewBool(ctx, 1);
    CHECK(JS_VALUE_GET_TAG(bool_value) == JS_TAG_BOOL);
    CHECK(JS_VALUE_GET_BOOL(bool_value) == 1);

    CHECK(JS_VALUE_GET_TAG(JS_NULL) == JS_TAG_NULL);
    CHECK(JS_VALUE_GET_TAG(JS_UNDEFINED) == JS_TAG_UNDEFINED);
    CHECK(JS_VALUE_GET_TAG(JS_EXCEPTION) == JS_TAG_EXCEPTION);

    int object_payload = 42;
    JSValue object_value = JS_MKPTR(JS_TAG_OBJECT, &object_payload);
    CHECK(JS_VALUE_GET_TAG(object_value) == JS_TAG_OBJECT);
    CHECK(JS_VALUE_GET_NORM_TAG(object_value) == JS_TAG_OBJECT);
    CHECK(JS_VALUE_GET_PTR(object_value) == &object_payload);
    CHECK(JS_VALUE_HAS_REF_COUNT(object_value));

    JSValue string_value = JS_MKPTR(JS_TAG_STRING, &object_payload);
    CHECK(JS_VALUE_GET_TAG(string_value) == JS_TAG_STRING);
    CHECK(JS_VALUE_GET_PTR(string_value) == &object_payload);
    CHECK(JS_VALUE_HAS_REF_COUNT(string_value));

    JSValue double_value = __JS_NewFloat64(ctx, 3.5);
    CHECK(JS_VALUE_GET_TAG(double_value) == JS_TAG_FLOAT64);
    CHECK(JS_VALUE_GET_NORM_TAG(double_value) == JS_TAG_FLOAT64);
    CHECK(JS_VALUE_GET_FLOAT64(double_value) == 3.5);
    CHECK(!JS_VALUE_IS_NAN(double_value));

    JSValue negative_zero = JS_NewFloat64(ctx, -0.0);
    CHECK(JS_VALUE_GET_TAG(negative_zero) == JS_TAG_FLOAT64);
    CHECK(double_bits(JS_VALUE_GET_FLOAT64(negative_zero)) == (uint64_t)0x8000000000000000);

    JSValue nan_value = __JS_NewFloat64(ctx, NAN);
    CHECK(JS_VALUE_GET_TAG(nan_value) == JS_TAG_FLOAT64);
    CHECK(JS_VALUE_GET_NORM_TAG(nan_value) == JS_TAG_FLOAT64);
    CHECK(JS_VALUE_IS_NAN(nan_value));

    return 0;
}
