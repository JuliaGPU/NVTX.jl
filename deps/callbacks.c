#include <stdint.h>
#include <nvToolsExt.h>

extern nvtxDomainHandle_t julia_domain;
extern nvtxStringHandle_t gc_message;
extern uint32_t gc_color;

extern void nvtx_julia_gc_cb_pre(int full) {
  nvtxEventAttributes_t eventAttrib = {0};
  eventAttrib.version = NVTX_VERSION;
  eventAttrib.size = NVTX_EVENT_ATTRIB_STRUCT_SIZE;
  eventAttrib.colorType = NVTX_COLOR_ARGB;
  eventAttrib.color = gc_color;
  eventAttrib.messageType = NVTX_MESSAGE_TYPE_REGISTERED;
  eventAttrib.message.registered = gc_message;
  eventAttrib.category = (uint32_t) full;
  nvtxDomainRangePushEx(julia_domain, &eventAttrib);
}

extern void nvtx_julia_gc_cb_post(int full) {
  nvtxDomainRangePop(julia_domain);
}