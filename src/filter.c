#define DDEBUG 0

#include "ddebug.h"
#include "filter.h"
#include "util.h"
#include "handler.h"

#include <ngx_log.h>

ngx_flag_t ngx_http_echo_filter_used = 0;

static ngx_http_output_header_filter_pt ngx_http_next_header_filter;

static ngx_http_output_body_filter_pt ngx_http_next_body_filter;

static ngx_int_t ngx_http_echo_header_filter(ngx_http_request_t *r);

static ngx_int_t ngx_http_echo_body_filter(ngx_http_request_t *r, ngx_chain_t *in);

/* filter handlers */
static ngx_int_t ngx_http_echo_exec_filter_cmds(ngx_http_request_t *r,
        ngx_http_echo_ctx_t *ctx, ngx_array_t *cmds, ngx_uint_t *iterator);

ngx_int_t
ngx_http_echo_filter_init (ngx_conf_t *cf) {
    if (ngx_http_echo_filter_used) {
        DD("top header filter: %ld", (unsigned long) ngx_http_top_header_filter);
        ngx_http_next_header_filter = ngx_http_top_header_filter;
        ngx_http_top_header_filter  = ngx_http_echo_header_filter;

        DD("top body filter: %ld", (unsigned long) ngx_http_top_body_filter);
        ngx_http_next_body_filter = ngx_http_top_body_filter;
        ngx_http_top_body_filter  = ngx_http_echo_body_filter;
    }

    return NGX_OK;
}

static ngx_int_t
ngx_http_echo_header_filter(ngx_http_request_t *r) {
    ngx_http_echo_loc_conf_t    *conf;
    ngx_http_echo_ctx_t         *ctx;
    ngx_int_t                   rc;

    DD("We're in the header filter...");

    ctx = ngx_http_get_module_ctx(r, ngx_http_echo_module);

    /* XXX we should add option to insert contents for responses
     * of non-200 status code here... */
    if (r->headers_out.status != NGX_HTTP_OK) {
        if (ctx != NULL) {
            ctx->skip_filter = 1;
        }
        return ngx_http_next_header_filter(r);
    }

    conf = ngx_http_get_module_loc_conf(r, ngx_http_echo_module);
    if (conf->before_body_cmds == NULL && conf->after_body_cmds == NULL) {
        if (ctx != NULL) {
            ctx->skip_filter = 1;
        }
        return ngx_http_next_header_filter(r);
    }

    if (ctx == NULL) {
        rc = ngx_http_echo_init_ctx(r, &ctx);
        if (rc != NGX_OK) {
            return NGX_ERROR;
        }
        ctx->headers_sent = 1;
        ngx_http_set_ctx(r, ctx, ngx_http_echo_module);
    }

    /* enable streaming here (use chunked encoding) */
    ngx_http_clear_content_length(r);
    ngx_http_clear_accept_ranges(r);

    return ngx_http_next_header_filter(r);
}

static ngx_int_t
ngx_http_echo_body_filter(ngx_http_request_t *r, ngx_chain_t *in) {
    ngx_http_echo_ctx_t         *ctx;
    ngx_int_t                   rc;
    ngx_http_echo_loc_conf_t    *conf;
    ngx_flag_t                  last;
    ngx_chain_t                 *cl;

    if (in == NULL || r->header_only) {
        return ngx_http_next_body_filter(r, in);
    }

    ctx = ngx_http_get_module_ctx(r, ngx_http_echo_module);

    if (ctx == NULL || ctx->skip_filter) {
        return ngx_http_next_body_filter(r, in);
    }

    conf = ngx_http_get_module_loc_conf(r, ngx_http_echo_module);

    if (!ctx->before_body_sent) {
        ctx->before_body_sent = 1;

        if (conf->before_body_cmds != NULL) {
            rc = ngx_http_echo_exec_filter_cmds(r, ctx, conf->before_body_cmds,
                    &ctx->next_before_body_cmd);
            if (rc != NGX_OK) {
                return NGX_ERROR;
            }
        }
    }

    if (conf->after_body_cmds == NULL) {
        ctx->skip_filter = 1;
        return ngx_http_next_body_filter(r, in);
    }

    last = 0;

    for (cl = in; cl; cl = cl->next) {
        if (cl->buf->last_buf) {
            cl->buf->last_buf = 0;
            cl->buf->sync = 1;
            last = 1;
        }
    }

    rc = ngx_http_next_body_filter(r, in);

    if (rc == NGX_ERROR || !last) {
        return rc;
    }

    DD("exec filter cmds for after body cmds");
    rc = ngx_http_echo_exec_filter_cmds(r, ctx, conf->after_body_cmds, &ctx->next_after_body_cmd);
    if (rc != NGX_OK) {
        DD("FAILED: exec filter cmds for after body cmds");
        return NGX_ERROR;
    }

    ctx->skip_filter = 1;

    DD("after body cmds executed...terminating...");

    return ngx_http_send_special(r, NGX_HTTP_LAST);
}

static ngx_int_t
ngx_http_echo_exec_filter_cmds(ngx_http_request_t *r,
        ngx_http_echo_ctx_t *ctx, ngx_array_t *cmds,
        ngx_uint_t *iterator) {
    ngx_int_t                   rc;
    ngx_array_t                 *computed_args = NULL;
    ngx_http_echo_cmd_t         *cmd;
    ngx_http_echo_cmd_t         *cmd_elts;

    cmd_elts = cmds->elts;
    for (; *iterator < cmds->nelts; (*iterator)++) {
        cmd = &cmd_elts[*iterator];

        /* evaluate arguments for the current cmd (if any) */
        if (cmd->args) {
            computed_args = ngx_array_create(r->pool, cmd->args->nelts,
                    sizeof(ngx_str_t));
            if (computed_args == NULL) {
                return NGX_HTTP_INTERNAL_SERVER_ERROR;
            }
            rc = ngx_http_echo_eval_cmd_args(r, cmd, computed_args);
            if (rc != NGX_OK) {
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                        "Failed to evaluate arguments for "
                        "the directive.");
                return rc;
            }
        }

        /* do command dispatch based on the opcode */
        switch (cmd->opcode) {
            case echo_opcode_echo_before_body:
            case echo_opcode_echo_after_body:
                DD("exec echo_before_body or echo_after_body...");
                rc = ngx_http_echo_exec_echo(r, ctx, computed_args);
                if (rc != NGX_OK) {
                    return rc;
                }
                break;
            default:
                break;
        }
    }

    return NGX_OK;
}
